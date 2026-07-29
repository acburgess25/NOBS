"""One briefing pipeline, shared by the request route and the scheduler.

The daily briefing is the product anchor, so there must be exactly one path that
produces it. Previously the `/briefing` route validated the model's JSON against
`BriefingSections` and merged in heuristic conflict detection, while the
scheduled path parsed the same JSON with bare `.get()` calls and skipped the
heuristics entirely — so an automatic morning briefing silently lost the
overload and overlap warnings that a manually requested one had, and unvalidated
model output reached storage. `generate_briefing` is now the only way to build
one.
"""

from __future__ import annotations

from datetime import UTC, date, datetime
from enum import Enum
import json

import httpx
from pydantic import BaseModel, Field

from app.config import Settings

_BRIEFING_SYSTEM_PROMPT = (
    "You are NOBS, a warm, concise, privacy-first personal assistant. "
    "Create a realistic daily briefing using ONLY the supplied calendar and "
    "reminder items. Never invent events, tasks, or context. Return only a JSON "
    "object with fields: topline (string), priorities (array of 3-5 strings), "
    "conflicts_or_risks (array of strings), recommended_plan (array of strings), "
    "one_useful_question (string or null), and suggested_next_actions (array of strings). "
    "Ask one useful question only when ambiguity is real; otherwise set it to null. "
    "Keep context boundaries clear by labeling Personal, Business, or Shared where useful."
)


class BriefingError(RuntimeError):
    """The briefing could not be produced."""


class BriefingModelUnavailable(BriefingError):
    """Ollama could not be reached."""


class BriefingModelFailed(BriefingError):
    """Ollama answered with an error status."""


class BriefingModelInvalid(BriefingError):
    """Ollama answered with something that is not a briefing."""


class PrivacyReceipt(BaseModel):
    used: list[str]
    processed: str
    shared: list[str]
    changed: list[str]


class BriefingContext(str, Enum):
    personal = "personal"
    business = "business"
    shared = "shared"


class BriefingCalendarItem(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    start: str = Field(min_length=1, max_length=50)
    end: str | None = Field(default=None, max_length=50)
    location: str | None = Field(default=None, max_length=300)
    context: BriefingContext


class BriefingReminderItem(BaseModel):
    title: str = Field(min_length=1, max_length=500)
    due: str | None = Field(default=None, max_length=50)
    context: BriefingContext


class BriefingRequest(BaseModel):
    date: date
    calendar: list[BriefingCalendarItem] = Field(max_length=100)
    reminders: list[BriefingReminderItem] = Field(max_length=100)


class BriefingSections(BaseModel):
    topline: str = Field(min_length=1, max_length=600)
    priorities: list[str] = Field(default_factory=list, max_length=5)
    conflicts_or_risks: list[str] = Field(default_factory=list, max_length=8)
    recommended_plan: list[str] = Field(default_factory=list, max_length=10)
    one_useful_question: str | None = Field(default=None, max_length=300)
    suggested_next_actions: list[str] = Field(default_factory=list, max_length=6)


class BriefingResponse(BriefingSections):
    date: date
    generated_at: datetime
    route: str
    privacy_receipt: PrivacyReceipt


class OllamaMessage(BaseModel):
    content: str


class OllamaResponse(BaseModel):
    message: OllamaMessage


async def generate_briefing(
    settings: Settings,
    request: BriefingRequest,
    transport: httpx.AsyncBaseTransport | None = None,
) -> BriefingResponse:
    """Build one validated briefing, heuristics included.

    Callers persist the result; this function has no store access so the same
    code serves the request route and the scheduler.
    """
    payload = {
        "model": settings.ollama_model,
        "stream": False,
        "think": False,
        "format": "json",
        "messages": [
            {"role": "system", "content": _BRIEFING_SYSTEM_PROMPT},
            {"role": "user", "content": json.dumps(request.model_dump(mode="json"))},
        ],
    }
    try:
        async with httpx.AsyncClient(
            timeout=settings.ollama_timeout_seconds,
            transport=transport,
        ) as client:
            response = await client.post(f"{settings.ollama_base_url}/api/chat", json=payload)
            response.raise_for_status()
    except (httpx.TimeoutException, httpx.ConnectError) as error:
        raise BriefingModelUnavailable("Tank model is unavailable") from error
    except httpx.HTTPStatusError as error:
        raise BriefingModelFailed("Tank model returned an error") from error

    try:
        model_content = OllamaResponse.model_validate_json(response.content).message.content
        sections = BriefingSections.model_validate_json(model_content)
    except ValueError as error:
        raise BriefingModelInvalid("Tank model returned an invalid briefing") from error

    sections = merge_briefing_with_heuristics(request, sections)
    return BriefingResponse(
        date=request.date,
        topline=sections.topline,
        priorities=sections.priorities,
        conflicts_or_risks=sections.conflicts_or_risks,
        recommended_plan=sections.recommended_plan,
        one_useful_question=sections.one_useful_question,
        suggested_next_actions=sections.suggested_next_actions,
        generated_at=datetime.now(UTC),
        route="Tank",
        privacy_receipt=PrivacyReceipt(
            used=[
                f"{len(request.calendar)} calendar items",
                f"{len(request.reminders)} reminder items",
            ],
            processed="Tank on your private network",
            shared=[],
            changed=[],
        ),
    )


# ------------------------------------------------------------------ #
# Heuristics                                                           #
# ------------------------------------------------------------------ #


def _time_to_minutes(value: str | None) -> int | None:
    if not value:
        return None
    try:
        hour, minute = value.strip().split(":", 1)
        parsed_hour = int(hour)
        parsed_minute = int(minute)
    except (ValueError, AttributeError):
        return None
    if parsed_hour < 0 or parsed_hour > 23 or parsed_minute < 0 or parsed_minute > 59:
        return None
    return parsed_hour * 60 + parsed_minute


def _is_important_title(title: str) -> bool:
    normalized = title.lower()
    important_keywords = (
        "deadline",
        "interview",
        "presentation",
        "board",
        "review",
        "flight",
        "doctor",
        "exam",
        "launch",
    )
    return any(keyword in normalized for keyword in important_keywords)


def _context_prefix(context: BriefingContext) -> str:
    if context == BriefingContext.business:
        return "Business"
    if context == BriefingContext.shared:
        return "Shared"
    return "Personal"


def _dedupe(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        trimmed = value.strip()
        if not trimmed:
            continue
        key = trimmed.casefold()
        if key in seen:
            continue
        seen.add(key)
        result.append(trimmed)
    return result


def _by_start_time(items: list[BriefingCalendarItem]) -> list[BriefingCalendarItem]:
    return sorted(
        items,
        key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
    )


def _detect_briefing_risks(request: BriefingRequest) -> tuple[list[str], bool]:
    risks: list[str] = []
    overload = False
    events = _by_start_time(request.calendar)
    if len(events) >= 7:
        overload = True
        risks.append(
            f"Your day has {len(events)} events, which is likely overload without active pruning."
        )

    back_to_back = 0
    overlaps = 0
    important_tight = 0
    morning_count = 0
    for index, event in enumerate(events):
        start_minutes = _time_to_minutes(event.start)
        if start_minutes is not None and start_minutes < (12 * 60):
            morning_count += 1
        if index >= len(events) - 1:
            continue
        current_end = _time_to_minutes(event.end) or start_minutes
        next_start = _time_to_minutes(events[index + 1].start)
        if current_end is None or next_start is None:
            continue
        gap = next_start - current_end
        if gap < 0:
            overlaps += 1
        elif gap <= 10:
            back_to_back += 1
        if (
            _is_important_title(event.title)
            and _is_important_title(events[index + 1].title)
            and gap <= 60
        ):
            important_tight += 1

    if overlaps > 0:
        overload = True
        risks.append(f"{overlaps} schedule overlap(s) need a clear attendance choice.")
    if back_to_back >= 2:
        overload = True
        risks.append(
            f"{back_to_back} tight transition(s) under 10 minutes increase prep or travel risk."
        )
    if important_tight > 0:
        overload = True
        risks.append("Important events are clustered too tightly; prep quality is at risk.")
    if morning_count >= 4:
        overload = True
        risks.append("Morning load is heavy with four or more events before noon.")
    business_reminders = sum(
        1 for reminder in request.reminders if reminder.context == BriefingContext.business
    )
    if request.reminders and business_reminders >= 3:
        risks.append("Several business reminders are pending; prep work may be under-scoped.")

    return _dedupe(risks), overload


def _fallback_topline(request: BriefingRequest, overload: bool, risk_count: int) -> str:
    if not request.calendar and not request.reminders:
        return "This is a light day with room to protect deep work and recovery."
    if overload:
        return "This is a high-load day; trimming and sequencing early will keep it realistic."
    if risk_count > 0:
        return "This day is manageable, but a few timing risks need attention."
    return "This is a steady day with enough space to execute your top priorities."


def _fallback_priorities(request: BriefingRequest) -> list[str]:
    ranked_events = sorted(
        request.calendar,
        key=lambda item: (
            not _is_important_title(item.title),
            _time_to_minutes(item.start) or 24 * 60,
        ),
    )
    priorities = [
        f"{_context_prefix(event.context)} · {event.title} ({event.start})"
        for event in ranked_events[:4]
    ]
    if len(priorities) < 3:
        priorities.extend(
            f"{_context_prefix(reminder.context)} · {reminder.title}"
            for reminder in request.reminders[: 5 - len(priorities)]
        )
    if not priorities:
        priorities.append("Protect one focused block for your highest-impact work.")
    return _dedupe(priorities)[:5]


def _fallback_recommended_plan(request: BriefingRequest) -> list[str]:
    events = _by_start_time(request.calendar)
    plan: list[str] = []
    if events:
        first = events[0]
        plan.append(
            f"Start with prep for {first.title} before {first.start} "
            "to avoid reactive context switching."
        )
    for event in events[:3]:
        plan.append(
            f"Anchor {_context_prefix(event.context).lower()} focus around "
            f"{event.title} at {event.start}."
        )
    if request.reminders:
        plan.append("Bundle reminder follow-ups into one admin block between meetings.")
    plan.append("Reassess afternoon priorities after lunch and drop low-impact work.")
    return _dedupe(plan)[:6]


def _fallback_question(request: BriefingRequest, risks: list[str]) -> str | None:
    events = _by_start_time(request.calendar)
    for index, event in enumerate(events[:-1]):
        current_end = _time_to_minutes(event.end)
        next_start = _time_to_minutes(events[index + 1].start)
        if current_end is None or next_start is None:
            continue
        if next_start < current_end:
            return (
                "You have overlapping events. Which one is the must-attend "
                "so I can adjust the rest?"
            )
    if risks and request.reminders:
        return "Which reminder is truly critical today so lower-value tasks can be deferred?"
    return None


def _fallback_next_actions(request: BriefingRequest, risks: list[str]) -> list[str]:
    actions: list[str] = []
    if request.calendar:
        first = _by_start_time(request.calendar)[0]
        actions.append(f"Review prep notes for {first.title} before {first.start}.")
    if risks:
        actions.append("Draft a conflict message for any meeting that can be moved or shortened.")
    if request.reminders:
        actions.append("Create a single prep reminder block to clear your highest-value tasks.")
    actions.append("Re-check afternoon priorities after your second major commitment.")
    return _dedupe(actions)[:4]


def merge_briefing_with_heuristics(
    request: BriefingRequest, sections: BriefingSections
) -> BriefingSections:
    """Add deterministic conflict detection on top of what the model returned.

    The model is told not to invent anything, which also means it cannot be
    relied on to spot overlaps or overload, so these risks are computed from the
    supplied items rather than requested.
    """
    heuristic_risks, overload = _detect_briefing_risks(request)
    merged_risks = _dedupe([*sections.conflicts_or_risks, *heuristic_risks])[:8]
    question = sections.one_useful_question.strip() if sections.one_useful_question else None
    if not question:
        question = _fallback_question(request, merged_risks)
    return BriefingSections(
        topline=sections.topline.strip()
        or _fallback_topline(request, overload=overload, risk_count=len(merged_risks)),
        priorities=(_dedupe(sections.priorities)[:5] or _fallback_priorities(request)),
        conflicts_or_risks=merged_risks or ["No major schedule risks detected right now."],
        recommended_plan=(
            _dedupe(sections.recommended_plan)[:10] or _fallback_recommended_plan(request)
        ),
        one_useful_question=question,
        suggested_next_actions=(
            _dedupe(sections.suggested_next_actions)[:6] or _fallback_next_actions(request, risks=merged_risks)
        ),
    )
