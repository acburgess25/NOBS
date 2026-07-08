from __future__ import annotations

import asyncio
import json
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings
from app.scheduler import (
    _IDEA_COOLDOWN,
    _IDEA_WINDOW_SECONDS,
    run_scheduler,
    trigger_briefing_generation,
)


def _scheduler_sleep_patch():
    real_sleep = asyncio.sleep

    async def cancel_after_pending_tasks(_: float) -> None:
        await real_sleep(0)
        current = asyncio.current_task()
        for task in list(asyncio.all_tasks()):
            if task is not current and not task.done():
                await task
        raise asyncio.CancelledError()

    return patch("app.scheduler.asyncio.sleep", new=cancel_after_pending_tasks)


def test_trigger_briefing_generation_persists_result(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    store.sync_calendar(
        [{"title": "Standup", "start": "09:00", "end": "09:30", "context": "business"}]
    )
    store.sync_reminders([{"title": "Buy milk", "due": "18:00", "context": "personal"}])

    def ollama_response(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        supplied = json.loads(payload["messages"][1]["content"])
        assert supplied["calendar"][0]["title"] == "Standup"
        assert supplied["reminders"][0]["title"] == "Buy milk"
        return httpx.Response(
            200,
            json={
                "message": {
                    "content": json.dumps(
                        {
                            "topline": "A balanced day.",
                            "priorities": ["Business · Standup (09:00)"],
                            "conflicts_or_risks": [],
                            "recommended_plan": ["Prep before 09:00."],
                            "one_useful_question": None,
                            "suggested_next_actions": ["Review agenda."],
                        }
                    )
                }
            },
        )

    settings = Settings(
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    transport = httpx.MockTransport(ollama_response)

    asyncio.run(trigger_briefing_generation(settings, store, transport))

    briefing = store.latest_briefing()
    assert briefing is not None
    assert briefing["topline"] == "A balanced day."
    assert briefing["route"] == "Tank"


def test_scheduler_triggers_briefing_for_active_schedule(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    fixed_now = datetime(2026, 7, 8, 8, 30, 5, tzinfo=UTC)
    store.create_briefing_schedule("08:30")

    settings = Settings(
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    tools = ToolRegistry(tmp_path / "workspace", store=store, settings=settings)
    trigger_mock = AsyncMock()

    with (
        patch("app.scheduler.datetime") as mock_datetime,
        patch("app.scheduler.trigger_briefing_generation", trigger_mock),
        _scheduler_sleep_patch(),
    ):
        mock_datetime.now.return_value = fixed_now
        mock_datetime.fromisoformat = datetime.fromisoformat
        with pytest.raises(asyncio.CancelledError):
            asyncio.run(run_scheduler(settings, store, tools))

    trigger_mock.assert_awaited_once()


def test_scheduler_skips_paused_and_revoked_schedules(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    fixed_now = datetime(2026, 7, 8, 8, 30, 5, tzinfo=UTC)
    paused = store.create_briefing_schedule("08:30")
    store.update_briefing_schedule(paused["id"], "paused")
    revoked = store.create_briefing_schedule("08:30")
    store.update_briefing_schedule(revoked["id"], "revoked")

    settings = Settings(
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    tools = ToolRegistry(tmp_path / "workspace", store=store, settings=settings)
    trigger_mock = AsyncMock()

    with (
        patch("app.scheduler.datetime") as mock_datetime,
        patch("app.scheduler.trigger_briefing_generation", trigger_mock),
        _scheduler_sleep_patch(),
    ):
        mock_datetime.now.return_value = fixed_now
        mock_datetime.fromisoformat = datetime.fromisoformat
        with pytest.raises(asyncio.CancelledError):
            asyncio.run(run_scheduler(settings, store, tools))

    trigger_mock.assert_not_awaited()


def test_scheduler_respects_idea_cooldown(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    store.create_proposal("Recent idea", "Still cooling down.", "optimization")
    fixed_now = datetime(2026, 7, 8, 12, 0, 5, tzinfo=UTC)
    assert _IDEA_WINDOW_SECONDS > 5

    settings = Settings(
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    tools = ToolRegistry(tmp_path / "workspace", store=store, settings=settings)
    idea_mock = AsyncMock()

    with (
        patch("app.scheduler.datetime") as mock_datetime,
        patch("app.scheduler.trigger_autonomous_idea", idea_mock),
        _scheduler_sleep_patch(),
    ):
        mock_datetime.now.return_value = fixed_now
        mock_datetime.fromisoformat = datetime.fromisoformat
        with pytest.raises(asyncio.CancelledError):
            asyncio.run(run_scheduler(settings, store, tools))

    idea_mock.assert_not_awaited()


def test_scheduler_triggers_idea_after_cooldown(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    proposal = store.create_proposal("Older idea", "Ready for another.", "routine")
    proposal_time = datetime.fromisoformat(proposal["created_at"])
    fixed_now = proposal_time + _IDEA_COOLDOWN + timedelta(minutes=1)
    fixed_now = fixed_now.replace(second=5, microsecond=0)
    assert fixed_now - proposal_time > _IDEA_COOLDOWN
    assert int(fixed_now.timestamp()) % 60 < _IDEA_WINDOW_SECONDS

    settings = Settings(
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    tools = ToolRegistry(tmp_path / "workspace", store=store, settings=settings)
    idea_mock = AsyncMock()

    with (
        patch("app.scheduler.datetime") as mock_datetime,
        patch("app.scheduler.trigger_autonomous_idea", idea_mock),
        _scheduler_sleep_patch(),
    ):
        mock_datetime.now.return_value = fixed_now
        mock_datetime.fromisoformat = datetime.fromisoformat
        with pytest.raises(asyncio.CancelledError):
            asyncio.run(run_scheduler(settings, store, tools))

    idea_mock.assert_awaited_once()


def test_scheduler_logs_store_errors_without_crashing(tmp_path: Path) -> None:
    store = MagicMock(spec=AgentStore)
    store.list_briefing_schedules.side_effect = OSError("database unavailable")
    store.last_proposal_at.return_value = None

    settings = Settings(
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    tools = ToolRegistry(tmp_path / "workspace", store=store, settings=settings)

    with (
        patch("app.scheduler.datetime") as mock_datetime,
        _scheduler_sleep_patch(),
    ):
        mock_datetime.now.return_value = datetime(2026, 7, 8, 9, 0, tzinfo=UTC)
        mock_datetime.fromisoformat = datetime.fromisoformat
        with pytest.raises(asyncio.CancelledError):
            asyncio.run(run_scheduler(settings, store, tools))
