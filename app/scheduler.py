import asyncio
import json
import logging
from datetime import UTC, datetime, timedelta
from typing import Any

import httpx

from app.agent import AgentTaskRequest, TankAgent
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
    "object with string fields personal, business, and shared. Keep all three "
    "sections clearly separate; use a brief 'Nothing scheduled' sentence when "
    "a section has no items."
)

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
        try:
            now = datetime.now(UTC)
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
                datetime.now(UTC) - datetime.fromisoformat(last_proposal) > _IDEA_COOLDOWN
            )
            elapsed = int(datetime.now(UTC).timestamp()) % 60
            if cooldown_expired and elapsed < _IDEA_WINDOW_SECONDS:
                logger.info("Triggering autonomous agent to propose an idea.")
                task = asyncio.create_task(
                    trigger_autonomous_idea(settings, store, tools, transport)
                )
                _background_tasks.add(task)
                task.add_done_callback(_background_tasks.discard)
        except Exception:
            logger.exception("Scheduler error during autonomous idea check")

        await asyncio.sleep(15)


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
    except Exception:
        logger.exception("Autonomous idea generation failed")


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
            response = await client.post(
                f"{settings.ollama_base_url}/api/chat", json=payload
            )
            response.raise_for_status()

        sections = json.loads(response.json()["message"]["content"])
        result = {
            "date": today.isoformat(),
            "personal": sections.get("personal", "Nothing scheduled."),
            "business": sections.get("business", "Nothing scheduled."),
            "shared": sections.get("shared", "Nothing scheduled."),
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

    except Exception:
        logger.exception("Failed to generate scheduled briefing")
