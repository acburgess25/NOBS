import asyncio
from datetime import UTC, datetime, date
import logging
import json
from typing import Any

from app.agent_store import AgentStore
from app.config import Settings
from app.agent import AgentTaskRequest, TankAgent
from app.agent_tools import ToolRegistry

logger = logging.getLogger(__name__)

async def run_scheduler(
    settings: Settings,
    store: AgentStore,
    tools: ToolRegistry,
    transport: Any = None,
) -> None:
    """Background task that runs every minute to trigger scheduled agent runs."""
    # Track the last minute we ran for to avoid double-triggering in the same minute
    last_triggered_minute = None

    while True:
        try:
            now = datetime.now(UTC)
            current_time = now.strftime("%H:%M")

            if current_time != last_triggered_minute:
                schedules = store.list_briefing_schedules(status="active")
                for schedule in schedules:
                    if schedule["time_of_day"] == current_time:
                        logger.info(f"Triggering briefing schedule {schedule['id']} for {current_time}")
                        
                        # Generate the briefing directly using the same logic as the POST /briefing endpoint,
                        # but sourcing data from the DB synced by the iOS app.
                        await trigger_briefing_generation(settings, store, transport)
                        
                        # Record the event
                        store.record_event(
                            "system_scheduler", 
                            "schedule_triggered", 
                            {"schedule_id": schedule["id"], "time": current_time}
                        )

                last_triggered_minute = current_time

        except Exception as e:
            logger.error(f"Scheduler error: {e}")

        # Sleep for a bit before checking again
        await asyncio.sleep(15)

async def trigger_briefing_generation(
    settings: Settings,
    store: AgentStore,
    transport: Any,
) -> None:
    calendar = store.list_calendar_events()
    reminders = store.list_reminders()

    # Match the format expected by the system prompt
    source = {
        "date": date.today().isoformat(),
        "calendar": calendar,
        "reminders": reminders,
    }

    payload = {
        "model": settings.ollama_model,
        "stream": False,
        "think": False,
        "format": "json",
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are NOBS, a warm, concise, privacy-first personal assistant. "
                    "Create a realistic daily briefing using ONLY the supplied calendar and "
                    "reminder items. Never invent events, tasks, or context. Return only a JSON "
                    "object with string fields personal, business, and shared. Keep all three "
                    "sections clearly separate; use a brief 'Nothing scheduled' sentence when "
                    "a section has no items."
                ),
            },
            {"role": "user", "content": json.dumps(source)},
        ],
    }

    import httpx
    try:
        async with httpx.AsyncClient(
            timeout=settings.ollama_timeout_seconds,
            transport=transport,
        ) as client:
            response = await client.post(f"{settings.ollama_base_url}/api/chat", json=payload)
            response.raise_for_status()
            
        data = response.json()
        model_content = data["message"]["content"]
        sections = json.loads(model_content)
        
        result = {
            "date": date.today().isoformat(),
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
            }
        }
        
        store.save_briefing(date.today().isoformat(), result)
        logger.info("Successfully generated and saved scheduled briefing.")
        
        # Also create a visible agent run so it shows in the dashboard
        run_id = store.create_run(
            objective="Autonomously generate the scheduled daily briefing based on the latest synced data.",
            context="personal"
        )
        store.record_event(run_id, "tool_executed", {"tool": "generate_briefing", "risk": "read_only", "result": result})
        store.update_run(run_id, "completed")
        
    except Exception as e:
        logger.error(f"Failed to generate scheduled briefing: {e}")
