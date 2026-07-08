from __future__ import annotations

import json
from datetime import date
from enum import Enum
from typing import Any, Literal

import httpx
from pydantic import BaseModel, Field

from app.config import Settings

BRIEFING_SYSTEM_PROMPT = (
    "You are NOBS, a warm, concise, privacy-first personal assistant. "
    "Create a realistic daily briefing using ONLY the supplied calendar and "
    "reminder items. Never invent events, tasks, or context. Return only a JSON "
    "object with fields: topline (string), priorities (array of 3-5 strings), "
    "conflicts_or_risks (array of strings), recommended_plan (array of strings), "
    "one_useful_question (string or null), and suggested_next_actions (array of strings). "
    "Ask one useful question only when ambiguity is real; otherwise set it to null. "
    "Keep context boundaries clear by labeling Personal, Business, or Shared where useful."
)

EVENING_BRIEFING_SYSTEM_PROMPT = (
    "You are NOBS, a warm, concise, privacy-first personal assistant. "
    "Create an evening wrap-up using ONLY the supplied calendar and reminder items. "
    "Never invent events, tasks, or guilt. Use a guilt-free, encouraging tone. "
    "Summarize accomplishments from today's calendar items that have passed, "
    "acknowledge unfinished commitments without blame, and prepare for tomorrow "
    "using tomorrow_calendar and tomorrow_reminders when provided. "
    "Return only a JSON object with fields: topline (string), priorities (array of 3-5 strings "
    "covering accomplishments and carry-over items), conflicts_or_risks (array of strings for "
    "unfinished commitments), recommended_plan (array of strings for tomorrow prep), "
    "one_useful_question (string or null — ask only about a real carry-over decision), "
    "and suggested_next_actions (array of strings for gentle wind-down or tomorrow setup). "
    "Label Personal, Business, or Shared where useful."
)


class BriefingModelError(Exception):
    """Base error for briefing generation failures."""


class BriefingUnavailableError(BriefingModelError):
    """Ollama is unreachable or timed out."""


class BriefingInvalidResponseError(BriefingModelError):
    """Ollama returned an HTTP error or malformed briefing JSON."""


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
    kind: Literal["morning", "evening"] = "morning"
    calendar: list[BriefingCalendarItem] = Field(max_length=100)
    reminders: list[BriefingReminderItem] = Field(max_length=100)
    tomorrow_calendar: list[BriefingCalendarItem] = Field(default_factory=list, max_length=100)
    tomorrow_reminders: list[BriefingReminderItem] = Field(default_factory=list, max_length=100)


class BriefingSections(BaseModel):
    topline: str = Field(min_length=1, max_length=600)
    priorities: list[str] = Field(default_factory=list, max_length=5)
    conflicts_or_risks: list[str] = Field(default_factory=list, max_length=8)
    recommended_plan: list[str] = Field(default_factory=list, max_length=10)
    one_useful_question: str | None = Field(default=None, max_length=300)
    suggested_next_actions: list[str] = Field(default_factory=list, max_length=6)


class OllamaMessage(BaseModel):
    content: str


class OllamaResponse(BaseModel):
    message: OllamaMessage


def briefing_source_payload(request: BriefingRequest) -> dict[str, Any]:
    return request.model_dump(mode="json")


def privacy_receipt_used_fields(request: BriefingRequest) -> list[str]:
    used_fields = [
        f"{len(request.calendar)} calendar items",
        f"{len(request.reminders)} reminder items",
    ]
    if request.kind == "evening":
        used_fields.extend(
            [
                f"{len(request.tomorrow_calendar)} tomorrow calendar items",
                f"{len(request.tomorrow_reminders)} tomorrow reminder items",
            ]
        )
    return used_fields


def briefing_request_from_synced_data(
    *,
    briefing_date: date,
    calendar: list[dict[str, Any]],
    reminders: list[dict[str, Any]],
    kind: Literal["morning", "evening"] = "morning",
    tomorrow_calendar: list[dict[str, Any]] | None = None,
    tomorrow_reminders: list[dict[str, Any]] | None = None,
) -> BriefingRequest:
    return BriefingRequest(
        date=briefing_date,
        kind=kind,
        calendar=[BriefingCalendarItem.model_validate(item) for item in calendar],
        reminders=[BriefingReminderItem.model_validate(item) for item in reminders],
        tomorrow_calendar=[
            BriefingCalendarItem.model_validate(item) for item in (tomorrow_calendar or [])
        ],
        tomorrow_reminders=[
            BriefingReminderItem.model_validate(item) for item in (tomorrow_reminders or [])
        ],
    )


def merge_briefing_with_heuristics(
    request: BriefingRequest, sections: BriefingSections
) -> BriefingSections:
    heuristic_risks, overload = _detect_briefing_risks(request)
    merged_risks = _dedupe([*sections.conflicts_or_risks, *heuristic_risks])[:8]
    question = sections.one_useful_question.strip() if sections.one_useful_question else None
    if not question:
        question = _fallback_question(request, merged_risks)
    return BriefingSections(
        topline=sections.topline.strip()
        or _fallback_topline(request, overload=overload, risk_count=len(merged_risks)),
        priorities=(
            _dedupe(sections.priorities)[:5]
            or _fallback_priorities(request)
        ),
        conflicts_or_risks=merged_risks or ["No major schedule risks detected right now."],
        recommended_plan=(
            _dedupe(sections.recommended_plan)[:10]
            or _fallback_recommended_plan(request)
        ),
        one_useful_question=question,
        suggested_next_actions=(
            _dedupe(sections.suggested_next_actions)[:6]
            or _fallback_next_actions(request, merged_risks)
        ),
    )


def merge_evening_briefing_with_heuristics(
    request: BriefingRequest, sections: BriefingSections
) -> BriefingSections:
    accomplishments = _evening_accomplishments(request)
    unfinished = _detect_evening_unfinished(request)
    merged_priorities = _dedupe([*sections.priorities, *accomplishments])[:5]
    if not merged_priorities:
        merged_priorities = accomplishments
    merged_unfinished = _dedupe([*sections.conflicts_or_risks, *unfinished])[:8]
    question = sections.one_useful_question.strip() if sections.one_useful_question else None
    if not question:
        question = _evening_question(request, merged_unfinished)
    return BriefingSections(
        topline=sections.topline.strip()
        or _evening_topline(request, unfinished_count=len(merged_unfinished)),
        priorities=merged_priorities or accomplishments,
        conflicts_or_risks=merged_unfinished or ["Nothing critical needs to carry into tomorrow."],
        recommended_plan=(
            _dedupe(sections.recommended_plan)[:10]
            or _evening_tomorrow_plan(request)
        ),
        one_useful_question=question,
        suggested_next_actions=(
            _dedupe(sections.suggested_next_actions)[:6]
            or _evening_next_actions(request, merged_unfinished)
        ),
    )


def apply_briefing_heuristics(
    request: BriefingRequest, sections: BriefingSections
) -> BriefingSections:
    if request.kind == "evening":
        return merge_evening_briefing_with_heuristics(request, sections)
    return merge_briefing_with_heuristics(request, sections)


async def generate_briefing_sections(
    settings: Settings,
    request: BriefingRequest,
    transport: Any = None,
) -> BriefingSections:
    system_prompt = (
        EVENING_BRIEFING_SYSTEM_PROMPT
        if request.kind == "evening"
        else BRIEFING_SYSTEM_PROMPT
    )
    payload = {
        "model": settings.ollama_model,
        "stream": False,
        "think": False,
        "format": "json",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": json.dumps(briefing_source_payload(request))},
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
        raise BriefingUnavailableError("Tank model is unavailable") from error
    except httpx.HTTPStatusError as error:
        raise BriefingInvalidResponseError("Tank model returned an error") from error

    try:
        model_content = OllamaResponse.model_validate_json(response.content).message.content
        sections = BriefingSections.model_validate_json(model_content)
    except ValueError as error:
        raise BriefingInvalidResponseError("Tank model returned an invalid briefing") from error

    return apply_briefing_heuristics(request, sections)


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


def _detect_briefing_risks(request: BriefingRequest) -> tuple[list[str], bool]:
    risks: list[str] = []
    overload = False
    events = sorted(
        request.calendar,
        key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
    )
    if len(events) >= 7:
        overload = True
        risks.append(f"Your day has {len(events)} events, which is likely overload without active pruning.")

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
        risks.append(
            "Important events are clustered too tightly; prep quality is at risk."
        )
    if morning_count >= 4:
        overload = True
        risks.append(
            "Morning load is heavy with four or more events before noon."
        )
    if request.reminders and sum(
        1 for reminder in request.reminders if reminder.context == BriefingContext.business
    ) >= 3:
        risks.append("Several business reminders are pending; prep work may be under-scoped.")

    return _dedupe(risks), overload


def _fallback_topline(
    request: BriefingRequest, overload: bool, risk_count: int
) -> str:
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
    events = sorted(
        request.calendar,
        key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
    )
    plan: list[str] = []
    if events:
        first = events[0]
        plan.append(
            f"Start with prep for {first.title} before {first.start} to avoid reactive context switching."
        )
    for event in events[:3]:
        plan.append(f"Anchor {_context_prefix(event.context).lower()} focus around {event.title} at {event.start}.")
    if request.reminders:
        plan.append("Bundle reminder follow-ups into one admin block between meetings.")
    plan.append("Reassess afternoon priorities after lunch and drop low-impact work.")
    return _dedupe(plan)[:6]


def _fallback_question(request: BriefingRequest, risks: list[str]) -> str | None:
    events = sorted(
        request.calendar,
        key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
    )
    for index, event in enumerate(events[:-1]):
        current_end = _time_to_minutes(event.end)
        next_start = _time_to_minutes(events[index + 1].start)
        if current_end is None or next_start is None:
            continue
        if next_start < current_end:
            return (
                "You have overlapping events. Which one is the must-attend so I can adjust the rest?"
            )
    if risks and request.reminders:
        return "Which reminder is truly critical today so lower-value tasks can be deferred?"
    return None


def _fallback_next_actions(request: BriefingRequest, risks: list[str]) -> list[str]:
    actions: list[str] = []
    if request.calendar:
        first = sorted(
            request.calendar,
            key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
        )[0]
        actions.append(f"Review prep notes for {first.title} before {first.start}.")
    if risks:
        actions.append("Draft a conflict message for any meeting that can be moved or shortened.")
    if request.reminders:
        actions.append("Create a single prep reminder block to clear your highest-value tasks.")
    actions.append("Re-check afternoon priorities after your second major commitment.")
    return _dedupe(actions)[:4]


def _detect_evening_unfinished(request: BriefingRequest) -> list[str]:
    unfinished: list[str] = []
    for reminder in request.reminders:
        unfinished.append(
            f"{_context_prefix(reminder.context)} · {reminder.title} (still open)"
        )
    if request.tomorrow_calendar:
        first = sorted(
            request.tomorrow_calendar,
            key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
        )[0]
        unfinished.append(
            f"Tomorrow starts with {_context_prefix(first.context).lower()} · {first.title} at {first.start}."
        )
    return _dedupe(unfinished)[:8]


def _evening_accomplishments(request: BriefingRequest) -> list[str]:
    accomplishments: list[str] = []
    for event in request.calendar:
        accomplishments.append(
            f"{_context_prefix(event.context)} · {event.title} ({event.start})"
        )
    if not accomplishments and not request.reminders:
        accomplishments.append("You protected space for rest and recovery today.")
    elif not accomplishments:
        accomplishments.append("You kept commitments moving even without fixed calendar blocks.")
    return _dedupe(accomplishments)[:5]


def _evening_topline(request: BriefingRequest, unfinished_count: int) -> str:
    event_count = len(request.calendar)
    if event_count == 0 and unfinished_count == 0:
        return "A calm day wraps up — tomorrow can stay light unless you choose otherwise."
    if unfinished_count == 0:
        return f"You moved through {event_count} commitment{'s' if event_count != 1 else ''} today. Nothing critical is left hanging."
    if unfinished_count == 1:
        return "Solid progress today — one item can roll forward without guilt."
    return (
        f"You made it through a full day. {unfinished_count} items can carry to tomorrow "
        "without needing to finish tonight."
    )


def _evening_tomorrow_plan(request: BriefingRequest) -> list[str]:
    plan: list[str] = []
    tomorrow_events = sorted(
        request.tomorrow_calendar,
        key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
    )
    if tomorrow_events:
        first = tomorrow_events[0]
        plan.append(f"First up tomorrow: {first.title} at {first.start}.")
    for event in tomorrow_events[:3]:
        plan.append(
            f"Block prep for {_context_prefix(event.context).lower()} · {event.title}."
        )
    if request.tomorrow_reminders:
        plan.append(
            f"{len(request.tomorrow_reminders)} reminder"
            f"{'s' if len(request.tomorrow_reminders) != 1 else ''} queued for tomorrow."
        )
    if not plan:
        plan.append("Tomorrow looks open — protect one block for what matters most.")
    plan.append("Wind down without reopening today's unfinished list unless it helps.")
    return _dedupe(plan)[:6]


def _evening_question(request: BriefingRequest, unfinished: list[str]) -> str | None:
    if len(unfinished) >= 2:
        return "Which carry-over item matters most tomorrow so the rest can wait?"
    if request.tomorrow_calendar and len(request.tomorrow_calendar) >= 4:
        return "Tomorrow looks packed — want to defer one lower-priority block now?"
    return None


def _evening_next_actions(request: BriefingRequest, unfinished: list[str]) -> list[str]:
    actions: list[str] = []
    if unfinished:
        actions.append("Pick one carry-over item to tackle first tomorrow — the rest can wait.")
    if request.tomorrow_calendar:
        first = sorted(
            request.tomorrow_calendar,
            key=lambda item: (_time_to_minutes(item.start) is None, _time_to_minutes(item.start) or 0),
        )[0]
        actions.append(f"Set a gentle prep reminder for {first.title} before bed.")
    actions.append("Close the day — unfinished work does not need guilt tonight.")
    return _dedupe(actions)[:4]
