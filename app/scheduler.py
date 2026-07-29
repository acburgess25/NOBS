import asyncio
from functools import lru_cache
import logging
from datetime import UTC, date, datetime, timedelta
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import httpx
import psutil

from app.agent import AgentModelError, AgentTaskRequest, TankAgent
from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.briefing import (
    BriefingCalendarItem,
    BriefingError,
    BriefingReminderItem,
    BriefingRequest,
    _time_to_minutes,
    generate_briefing,
)
from app.config import Settings

logger = logging.getLogger(__name__)

# Seconds elapsed within each scheduler cycle (mod 60) below which autonomous
# idea generation is allowed to fire.  Keeps it to at most once per minute.
_IDEA_WINDOW_SECONDS = 15

# Minimum time between autonomous idea proposals regardless of their status.
# Prevents flooding even if the user hasn't reviewed previous proposals.
_IDEA_COOLDOWN = timedelta(hours=1)

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
            current_time = local_hhmm(settings, now)

            if current_time != last_triggered_minute:
                schedules = store.list_briefing_schedules(status="active")
                due = due_schedules(schedules, current_time)
                if due:
                    logger.info(
                        "Triggering briefing schedule(s) %s for %s local",
                        ", ".join(schedule["id"] for schedule in due),
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


def local_now(settings: Settings, now_utc: datetime) -> datetime:
    """`now_utc` in the user's configured timezone."""
    return now_utc.astimezone(_resolve_timezone(settings.timezone))


def local_hhmm(settings: Settings, now_utc: datetime) -> str:
    return local_now(settings, now_utc).strftime("%H:%M")


def local_today(settings: Settings, now_utc: datetime) -> date:
    """The user's current local date.

    Not the UTC date: at 23:30 in Chicago the UTC date is already tomorrow, which
    would file the briefing under the wrong day.
    """
    return local_now(settings, now_utc).date()


def due_schedules(
    schedules: list[dict[str, Any]],
    current_hhmm: str,
) -> list[dict[str, Any]]:
    """Schedules whose local wall-clock time matches `current_hhmm`.

    Schedules are created as local times -- "07:00" means 07:00 where the user
    lives -- so the caller must pass a local time (see `local_hhmm`). Matching
    against UTC fired a 7am briefing at 2am local for a user in Chicago, which
    broke the product's anchor feature.
    """
    return [schedule for schedule in schedules if schedule["time_of_day"] == current_hhmm]


@lru_cache(maxsize=8)
def _resolve_timezone(name: str) -> ZoneInfo:
    """Cached so an invalid NOBS_TIMEZONE warns once, not on every tick."""
    try:
        return ZoneInfo(name or "UTC")
    except (ZoneInfoNotFoundError, ValueError):
        logger.warning("Unrecognized NOBS_TIMEZONE %r; falling back to UTC.", name)
        return ZoneInfo("UTC")


def is_overnight_window(settings: Settings, now_utc: datetime) -> bool:
    """Return True when `now_utc`, converted to the configured timezone, falls
    inside the configured overnight window. The window may wrap past midnight
    (e.g. 23:00 -> 06:00)."""
    here = local_now(settings, now_utc)
    now_minutes = here.hour * 60 + here.minute

    start_minutes = _time_to_minutes(settings.overnight_window_start)
    end_minutes = _time_to_minutes(settings.overnight_window_end)
    if start_minutes is None:
        start_minutes = 23 * 60
    if end_minutes is None:
        end_minutes = 6 * 60

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


def _briefing_request_from_store(store: AgentStore, today: Any) -> BriefingRequest:
    """Rebuild the same request shape the /briefing route validates.

    Synced rows carry the end time, location, and due date, so the scheduled
    briefing sees exactly what a requested one does — without end times the
    heuristics could not detect overlaps at all.
    """
    calendar = [
        BriefingCalendarItem(
            title=row["title"],
            start=row["start"],
            end=row.get("end"),
            location=row.get("location"),
            context=row["context"],
        )
        for row in store.list_calendar_events()
    ]
    reminders = [
        BriefingReminderItem(
            title=row["title"],
            due=row.get("due"),
            context=row["context"],
        )
        for row in store.list_reminders()
    ]
    return BriefingRequest(date=today, calendar=calendar, reminders=reminders)


async def trigger_briefing_generation(
    settings: Settings,
    store: AgentStore,
    transport: Any,
) -> None:
    """Generate a daily briefing from synced calendar/reminder data and persist it.

    This goes through the same `generate_briefing` pipeline as `POST /briefing`,
    so a scheduled briefing is validated and gets the same heuristic conflict
    detection. It previously parsed model output with bare `.get()` calls and
    skipped the heuristics, which quietly made automatic briefings weaker than
    requested ones and let unvalidated output reach storage.
    """
    today = local_today(settings, datetime.now(UTC))

    try:
        request = _briefing_request_from_store(store, today)
    except ValueError as error:
        logger.exception("Synced calendar or reminder rows are unusable: %s", error)
        return

    try:
        result = await generate_briefing(settings, request, transport)
    except BriefingError as error:
        logger.warning("Failed to generate scheduled briefing: %s", error)
        return

    payload = result.model_dump(mode="json")
    store.save_briefing(today.isoformat(), payload)
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
        {"tool": "generate_briefing", "risk": "read_only", "result": payload},
    )
    store.update_run(run_id, "completed")
