import asyncio
import json
import logging
from datetime import UTC, datetime, timedelta
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import httpx
import psutil

from app.agent import AgentModelError, AgentTaskRequest, TankAgent
from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings

logger = logging.getLogger(__name__)

# Seconds elapsed within each scheduler cycle (mod 60) below which autonomous
# idea generation is allowed to fire.  Keeps it to at most once per minute.
_IDEA_WINDOW_SECONDS = 15

# Minimum time between autonomous idea proposals regardless of their status.
# Prevents flooding even if the user hasn't reviewed previous proposals.
_IDEA_COOLDOWN = timedelta(hours=1)

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

_IDEA_OBJECTIVE = (
    "You are NOBS. Come up with a single, highly useful smart home routine or "
    "system optimization idea that would benefit the user. Use the `propose_idea` "
    "tool to submit it for approval. Do not do anything else."
)

# Overnight tasks are deferred, evening-queued work (research, memory
# consolidation, briefing prep, etc.) processed one at a time while Tank is
# idle and inside the configured overnight window. See docs/TANK_AGENT_CORE.md.
_OVERNIGHT_TASK_TYPES = frozenset(
    {"research", "memory_consolidation", "briefing_prep", "custom"}
)


async def run_scheduler(
    settings: Settings,
    store: AgentStore,
    tools: ToolRegistry,
    transport: Any = None,
) -> None:
    """Background task: fires scheduled briefings and autonomous idea proposals."""
    last_triggered_minute: str | None = None
    _background_tasks: set[asyncio.Task[None]] = set()
    overnight_state: dict[str, bool] = {"running": False}

    while True:
        now = datetime.now(UTC)
        try:
            current_time = now.strftime("%H:%M")

            if current_time != last_triggered_minute:
                schedules = store.list_briefing_schedules(status="active")
                for schedule in schedules:
                    if schedule["time_of_day"] == current_time:
                        logger.info(
                            "Triggering briefing schedule %s for %s",
                            schedule["id"],
                            current_time,
                        )
                        await trigger_briefing_generation(settings, store, transport)

                last_triggered_minute = current_time

        except Exception:
            logger.exception("Scheduler error during briefing check")

        try:
            last_proposal = store.last_proposal_at()
            cooldown_expired = last_proposal is None or (
                now - datetime.fromisoformat(last_proposal) > _IDEA_COOLDOWN
            )
            elapsed = int(now.timestamp()) % 60
            if cooldown_expired and elapsed < _IDEA_WINDOW_SECONDS:
                logger.info("Triggering autonomous agent to propose an idea.")
                task = asyncio.create_task(
                    trigger_autonomous_idea(settings, store, tools, transport)
                )
                _background_tasks.add(task)
                task.add_done_callback(_background_tasks.discard)
        except Exception:
            logger.exception("Scheduler error during autonomous idea check")

        try:
            if (
                settings.overnight_queue_enabled
                and not overnight_state["running"]
                and is_overnight_window(settings, now)
                and is_tank_idle(settings)
            ):
                next_task = store.claim_next_overnight_task()
                if next_task is not None:
                    overnight_state["running"] = True
                    logger.info(
                        "Dequeuing overnight task %s (%s) for overnight processing.",
                        next_task["id"],
                        next_task["task_type"],
                    )
                    task = asyncio.create_task(
                        process_overnight_task(
                            settings, store, tools, transport, next_task, overnight_state
                        )
                    )
                    _background_tasks.add(task)
                    task.add_done_callback(_background_tasks.discard)
        except Exception:
            logger.exception("Scheduler error during overnight queue check")

        await asyncio.sleep(15)


def _resolve_timezone(name: str) -> ZoneInfo:
    try:
        return ZoneInfo(name or "UTC")
    except (ZoneInfoNotFoundError, ValueError):
        logger.warning("Unrecognized NOBS_TIMEZONE %r; falling back to UTC.", name)
        return ZoneInfo("UTC")


def _parse_hhmm(value: str) -> tuple[int, int] | None:
    try:
        hour_text, minute_text = value.strip().split(":", 1)
        hour, minute = int(hour_text), int(minute_text)
    except (ValueError, AttributeError):
        return None
    if 0 <= hour <= 23 and 0 <= minute <= 59:
        return hour, minute
    return None


def is_overnight_window(settings: Settings, now_utc: datetime) -> bool:
    """Return True when `now_utc`, converted to the configured timezone, falls
    inside the configured overnight window. The window may wrap past midnight
    (e.g. 23:00 -> 06:00)."""
    tz = _resolve_timezone(settings.timezone)
    local_now = now_utc.astimezone(tz)
    now_minutes = local_now.hour * 60 + local_now.minute

    start = _parse_hhmm(settings.overnight_window_start) or (23, 0)
    end = _parse_hhmm(settings.overnight_window_end) or (6, 0)
    start_minutes = start[0] * 60 + start[1]
    end_minutes = end[0] * 60 + end[1]

    if start_minutes == end_minutes:
        return False
    if start_minutes < end_minutes:
        return start_minutes <= now_minutes < end_minutes
    return now_minutes >= start_minutes or now_minutes < end_minutes


def is_tank_idle(settings: Settings) -> bool:
    """Cheap idle heuristic: recent CPU load at or below the configured threshold.

    This intentionally yields quickly to any foreground workload rather than
    trying to model "idle" precisely; the overnight window already restricts
    processing to configured off-hours.
    """
    try:
        cpu_percent = psutil.cpu_percent(interval=0.3)
    except OSError:
        # Some sandboxes/containers cannot read load metrics; fail open so the
        # overnight window itself still gates processing.
        return True
    return cpu_percent <= settings.overnight_idle_cpu_percent


async def process_overnight_task(
    settings: Settings,
    store: AgentStore,
    tools: ToolRegistry,
    transport: Any,
    task: dict[str, Any],
    state: dict[str, bool],
) -> None:
    """Run one claimed overnight task through the agent and record the outcome.

    Uses the same tool registry and approval policy as any other agent run:
    read-only tools execute automatically, and state-changing tools still
    create a pending approval rather than bypassing consent.
    """
    task_id = task["id"]
    try:
        agent = TankAgent(settings=settings, tools=tools, store=store, transport=transport)
        request = AgentTaskRequest(
            objective=task["objective"],
            context=task["context"],
            mode=task["mode"],
        )
        response = await agent.run(request)
        store.complete_overnight_task(task_id, response.model_dump(mode="json"))
        logger.info("Completed overnight task %s (%s).", task_id, task["task_type"])
    except (AgentModelError, httpx.HTTPError, ValueError, TypeError, OSError) as error:
        logger.exception("Overnight task %s failed: %s", task_id, error)
        try:
            store.fail_overnight_task(task_id, str(error))
        except ValueError:
            logger.exception("Could not record failure for overnight task %s", task_id)
    finally:
        state["running"] = False


async def trigger_autonomous_idea(
    settings: Settings,
    store: AgentStore,
    tools: ToolRegistry,
    transport: Any,
) -> None:
    """Ask the agent to propose one smart-home or system optimization idea."""
    agent = TankAgent(settings=settings, tools=tools, store=store, transport=transport)
    request = AgentTaskRequest(objective=_IDEA_OBJECTIVE, context="personal")
    try:
        await agent.run(request)
    except (AgentModelError, httpx.HTTPError, ValueError, TypeError, OSError) as error:
        logger.exception("Autonomous idea generation failed: %s", error)


async def trigger_briefing_generation(
    settings: Settings,
    store: AgentStore,
    transport: Any,
) -> None:
    """Generate a daily briefing from synced calendar/reminder data and persist it."""
    calendar = store.list_calendar_events()
    reminders = store.list_reminders()
    today = datetime.now(UTC).date()

    source = {
        "date": today.isoformat(),
        "calendar": calendar,
        "reminders": reminders,
    }
    payload = {
        "model": settings.ollama_model,
        "stream": False,
        "think": False,
        "format": "json",
        "messages": [
            {"role": "system", "content": _BRIEFING_SYSTEM_PROMPT},
            {"role": "user", "content": json.dumps(source)},
        ],
    }

    try:
        async with httpx.AsyncClient(
            timeout=settings.ollama_timeout_seconds,
            transport=transport,
        ) as client:
            response = await client.post(f"{settings.ollama_base_url}/api/chat", json=payload)
            response.raise_for_status()

        sections = json.loads(response.json()["message"]["content"])
        result = {
            "date": today.isoformat(),
            "topline": sections.get(
                "topline",
                "This day needs active prioritization to stay realistic.",
            ),
            "priorities": sections.get("priorities", []),
            "conflicts_or_risks": sections.get("conflicts_or_risks", []),
            "recommended_plan": sections.get("recommended_plan", []),
            "one_useful_question": sections.get("one_useful_question"),
            "suggested_next_actions": sections.get("suggested_next_actions", []),
            "generated_at": datetime.now(UTC).isoformat(),
            "route": "Tank",
            "privacy_receipt": {
                "used": [
                    f"{len(calendar)} calendar items",
                    f"{len(reminders)} reminder items",
                ],
                "processed": "Tank on your private network",
                "shared": [],
                "changed": [],
            },
        }

        store.save_briefing(today.isoformat(), result)
        logger.info("Generated and saved scheduled briefing for %s.", today.isoformat())

        run_id = store.create_run(
            objective=(
                "Autonomously generate the scheduled daily briefing "
                "based on the latest synced data."
            ),
            context="personal",
        )
        store.record_event(
            run_id,
            "tool_executed",
            {"tool": "generate_briefing", "risk": "read_only", "result": result},
        )
        store.update_run(run_id, "completed")

    except (httpx.HTTPError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        logger.exception("Failed to generate scheduled briefing: %s", error)
