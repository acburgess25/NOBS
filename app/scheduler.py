import asyncio
import logging
import sqlite3
from datetime import datetime, timedelta
from typing import Any

import httpx

from app.agent import AgentModelError, AgentTaskRequest, TankAgent
from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.briefing import (
    BriefingModelError,
    briefing_request_from_synced_data,
    generate_briefing_sections,
    privacy_receipt_used_fields,
)
from app.config import Settings
from app.tank_time import local_time_label, utc_now

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


async def run_scheduler(
    settings: Settings,
    store: AgentStore,
    tools: ToolRegistry,
    transport: Any = None,
) -> None:
    """Background task: fires scheduled briefings and autonomous idea proposals."""
    last_triggered_minute: str | None = None
    _background_tasks: set[asyncio.Task[None]] = set()

    while True:
        utc = utc_now()
        try:
            current_time = local_time_label(settings.timezone)

            if current_time != last_triggered_minute:
                schedules = store.list_briefing_schedules(status="active")
                for schedule in schedules:
                    if schedule["time_of_day"] == current_time:
                        logger.info(
                            "Triggering briefing schedule %s for %s (%s)",
                            schedule["id"],
                            current_time,
                            settings.timezone,
                        )
                        await trigger_briefing_generation(settings, store, transport)

                last_triggered_minute = current_time

        except (OSError, sqlite3.Error, KeyError, TypeError, ValueError) as error:
            logger.exception("Scheduler error during briefing check: %s", error)

        try:
            last_proposal = store.last_proposal_at()
            cooldown_expired = last_proposal is None or (
                utc - datetime.fromisoformat(last_proposal) > _IDEA_COOLDOWN
            )
            elapsed = int(utc.timestamp()) % 60
            if cooldown_expired and elapsed < _IDEA_WINDOW_SECONDS:
                logger.info("Triggering autonomous agent to propose an idea.")
                task = asyncio.create_task(
                    trigger_autonomous_idea(settings, store, tools, transport)
                )
                _background_tasks.add(task)
                task.add_done_callback(_background_tasks.discard)
        except (OSError, sqlite3.Error, ValueError, TypeError) as error:
            logger.exception("Scheduler error during autonomous idea check: %s", error)

        await asyncio.sleep(15)


async def trigger_autonomous_idea(
    settings: Settings,
    store: AgentStore,
    tools: ToolRegistry,
    transport: Any,
) -> None:
    """Ask the agent to propose one smart-home or system optimization idea."""
    agent = TankAgent(settings=settings, tools=tools, store=store, transport=transport)
    request = AgentTaskRequest(
        objective=_IDEA_OBJECTIVE,
        context="personal",
        triggered_by="scheduler",
    )
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
    today = utc_now().date()
    request = briefing_request_from_synced_data(
        briefing_date=today,
        calendar=calendar,
        reminders=reminders,
        kind="morning",
    )

    try:
        sections = await generate_briefing_sections(settings, request, transport=transport)
        result = {
            "date": today.isoformat(),
            "kind": "morning",
            "topline": sections.topline,
            "priorities": sections.priorities,
            "conflicts_or_risks": sections.conflicts_or_risks,
            "recommended_plan": sections.recommended_plan,
            "one_useful_question": sections.one_useful_question,
            "suggested_next_actions": sections.suggested_next_actions,
            "generated_at": utc_now().isoformat(),
            "route": "Tank",
            "privacy_receipt": {
                "used": privacy_receipt_used_fields(request),
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
            triggered_by="scheduler",
        )
        store.record_event(
            run_id,
            "tool_executed",
            {"tool": "generate_briefing", "risk": "read_only", "result": result},
        )
        store.update_run(run_id, "completed")

    except (BriefingModelError, httpx.HTTPError, ValueError, TypeError) as error:
        logger.exception("Failed to generate scheduled briefing: %s", error)
