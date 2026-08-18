"""Tests for the overnight Tank queue: storage, window/idle detection, the
scheduler's task runner, and the REST surface."""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch

import httpx
import pytest

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings
from app.scheduler import is_overnight_window, is_tank_idle, process_overnight_task
from tests.test_chat import auth, client

# ------------------------------------------------------------------ #
# AgentStore: overnight_tasks CRUD and atomic claim                   #
# ------------------------------------------------------------------ #


def test_enqueue_and_get_overnight_task() -> None:
    store = AgentStore(Path(":memory:"))
    task = store.enqueue_overnight_task(
        objective="Research the best local backup strategy",
        context="personal",
        task_type="research",
    )
    assert task["status"] == "queued"
    assert task["mode"] == "assistant"
    assert task["priority"] == 0
    assert task["result"] is None
    assert store.get_overnight_task(task["id"]) == task


def test_get_missing_overnight_task_raises_key_error() -> None:
    store = AgentStore(Path(":memory:"))
    with pytest.raises(KeyError):
        store.get_overnight_task("does-not-exist")


def test_list_overnight_tasks_filters_by_status_and_orders_by_priority() -> None:
    store = AgentStore(Path(":memory:"))
    low = store.enqueue_overnight_task("Low priority", "personal", "custom", priority=0)
    high = store.enqueue_overnight_task("High priority", "personal", "custom", priority=5)
    also_low = store.enqueue_overnight_task("Also queued", "personal", "custom", priority=0)
    claimed = store.claim_next_overnight_task()
    assert claimed["id"] == high["id"]

    queued = store.list_overnight_tasks(status="queued")
    assert [item["id"] for item in queued] == [low["id"], also_low["id"]]
    assert all(item["status"] == "queued" for item in queued)

    running = store.list_overnight_tasks(status="running")
    assert [item["id"] for item in running] == [high["id"]]


def test_claim_next_overnight_task_is_atomic_and_priority_ordered() -> None:
    store = AgentStore(Path(":memory:"))
    first = store.enqueue_overnight_task("First queued", "personal", "custom", priority=1)
    second = store.enqueue_overnight_task(
        "Second queued, higher priority", "personal", "custom", priority=3
    )

    claimed = store.claim_next_overnight_task()
    assert claimed["id"] == second["id"]
    assert claimed["status"] == "running"
    assert claimed["started_at"] is not None

    # The higher-priority task cannot be claimed again; the next call gets
    # whatever remains queued.
    next_claim = store.claim_next_overnight_task()
    assert next_claim["id"] == first["id"]

    assert store.claim_next_overnight_task() is None


def test_claim_next_overnight_task_returns_none_when_empty() -> None:
    store = AgentStore(Path(":memory:"))
    assert store.claim_next_overnight_task() is None


def test_complete_overnight_task_requires_running_status() -> None:
    store = AgentStore(Path(":memory:"))
    task = store.enqueue_overnight_task("Do research", "personal", "research")
    with pytest.raises(ValueError):
        store.complete_overnight_task(task["id"], {"ok": True})

    store.claim_next_overnight_task()
    completed = store.complete_overnight_task(task["id"], {"ok": True})
    assert completed["status"] == "completed"
    assert completed["result"] == {"ok": True}
    assert completed["completed_at"] is not None


def test_fail_overnight_task_requires_running_status() -> None:
    store = AgentStore(Path(":memory:"))
    task = store.enqueue_overnight_task("Do research", "personal", "research")
    store.claim_next_overnight_task()
    failed = store.fail_overnight_task(task["id"], "model unavailable")
    assert failed["status"] == "failed"
    assert failed["error"] == "model unavailable"


def test_cancel_overnight_task_only_while_queued() -> None:
    store = AgentStore(Path(":memory:"))
    task = store.enqueue_overnight_task("Consolidate memory", "personal", "memory_consolidation")

    cancelled = store.cancel_overnight_task(task["id"])
    assert cancelled["status"] == "cancelled"

    with pytest.raises(ValueError):
        store.cancel_overnight_task(task["id"])


def test_cannot_cancel_a_running_task() -> None:
    store = AgentStore(Path(":memory:"))
    task = store.enqueue_overnight_task("Prep briefing", "personal", "briefing_prep")
    store.claim_next_overnight_task()
    with pytest.raises(ValueError):
        store.cancel_overnight_task(task["id"])


# ------------------------------------------------------------------ #
# Overnight window + idle detection                                   #
# ------------------------------------------------------------------ #


def test_overnight_window_simple_range() -> None:
    settings = Settings(
        timezone="UTC",
        overnight_window_start="01:00",
        overnight_window_end="05:00",
    )
    assert is_overnight_window(settings, datetime(2026, 7, 8, 3, 0, tzinfo=UTC))
    assert not is_overnight_window(settings, datetime(2026, 7, 8, 12, 0, tzinfo=UTC))
    assert not is_overnight_window(settings, datetime(2026, 7, 8, 5, 0, tzinfo=UTC))


def test_overnight_window_wraps_midnight() -> None:
    settings = Settings(
        timezone="UTC",
        overnight_window_start="23:00",
        overnight_window_end="06:00",
    )
    assert is_overnight_window(settings, datetime(2026, 7, 8, 23, 30, tzinfo=UTC))
    assert is_overnight_window(settings, datetime(2026, 7, 8, 2, 0, tzinfo=UTC))
    assert not is_overnight_window(settings, datetime(2026, 7, 8, 12, 0, tzinfo=UTC))
    assert not is_overnight_window(settings, datetime(2026, 7, 8, 6, 0, tzinfo=UTC))


def test_overnight_window_respects_configured_timezone() -> None:
    # 23:30 America/Chicago (UTC-5 in July) is 04:30 UTC the next day.
    settings = Settings(
        timezone="America/Chicago",
        overnight_window_start="23:00",
        overnight_window_end="06:00",
    )
    assert is_overnight_window(settings, datetime(2026, 7, 9, 4, 30, tzinfo=UTC))
    assert not is_overnight_window(settings, datetime(2026, 7, 8, 18, 0, tzinfo=UTC))


def test_overnight_window_falls_back_to_utc_for_unknown_timezone() -> None:
    settings = Settings(
        timezone="Not/ARealZone",
        overnight_window_start="23:00",
        overnight_window_end="06:00",
    )
    assert is_overnight_window(settings, datetime(2026, 7, 8, 23, 30, tzinfo=UTC))


def test_is_tank_idle_uses_configured_threshold() -> None:
    settings = Settings(overnight_idle_cpu_percent=40.0)
    with patch("app.scheduler.psutil.cpu_percent", return_value=10.0):
        assert is_tank_idle(settings) is True
    with patch("app.scheduler.psutil.cpu_percent", return_value=90.0):
        assert is_tank_idle(settings) is False


def test_is_tank_idle_fails_open_when_metrics_unavailable() -> None:
    settings = Settings(overnight_idle_cpu_percent=40.0)
    with patch("app.scheduler.psutil.cpu_percent", side_effect=OSError("unobtainable")):
        assert is_tank_idle(settings) is True


# ------------------------------------------------------------------ #
# process_overnight_task: runs one claimed task through the agent     #
# ------------------------------------------------------------------ #


def test_process_overnight_task_completes_read_only_objective(tmp_path: Path) -> None:
    settings = Settings(agent_workspace_path=tmp_path)
    store = AgentStore(Path(":memory:"))
    tools = ToolRegistry(tmp_path, store=store, settings=settings)
    task = store.enqueue_overnight_task("Check Tank status overnight", "personal", "research")
    claimed = store.claim_next_overnight_task()

    def ollama_response(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"message": {"content": "Everything looks healthy."}})

    state = {"running": True}
    asyncio.run(
        process_overnight_task(
            settings,
            store,
            tools,
            httpx.MockTransport(ollama_response),
            claimed,
            state,
        )
    )

    finished = store.get_overnight_task(task["id"])
    assert finished["status"] == "completed"
    assert finished["result"]["message"] == "Everything looks healthy."
    assert state["running"] is False


def test_process_overnight_task_records_failure_on_model_error(tmp_path: Path) -> None:
    settings = Settings(agent_workspace_path=tmp_path)
    store = AgentStore(Path(":memory:"))
    tools = ToolRegistry(tmp_path, store=store, settings=settings)
    task = store.enqueue_overnight_task("Research something", "personal", "research")
    claimed = store.claim_next_overnight_task()

    def ollama_response(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, text="model down")

    state = {"running": True}
    asyncio.run(
        process_overnight_task(
            settings,
            store,
            tools,
            httpx.MockTransport(ollama_response),
            claimed,
            state,
        )
    )

    finished = store.get_overnight_task(task["id"])
    assert finished["status"] == "failed"
    assert finished["error"]
    assert state["running"] is False


# ------------------------------------------------------------------ #
# REST surface                                                        #
# ------------------------------------------------------------------ #


def test_enqueue_overnight_task_via_api(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)
    response = test_client.post(
        "/overnight/tasks",
        json={
            "objective": "Consolidate this week's memory candidates",
            "context": "personal",
            "task_type": "memory_consolidation",
            "priority": 2,
        },
        headers=auth(),
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "queued"
    assert payload["task_type"] == "memory_consolidation"
    assert payload["priority"] == 2


def test_overnight_routes_require_device_authentication(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)
    assert test_client.get("/overnight/tasks").status_code == 401
    assert (
        test_client.post(
            "/overnight/tasks",
            json={"objective": "Research", "task_type": "research"},
        ).status_code
        == 401
    )


def test_list_and_get_overnight_task_via_api(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)
    created = test_client.post(
        "/overnight/tasks",
        json={"objective": "Prep tomorrow's briefing", "task_type": "briefing_prep"},
        headers=auth(),
    ).json()

    listed = test_client.get("/overnight/tasks", headers=auth())
    assert listed.status_code == 200
    assert any(item["id"] == created["id"] for item in listed.json())

    fetched = test_client.get(f"/overnight/tasks/{created['id']}", headers=auth())
    assert fetched.status_code == 200
    assert fetched.json()["id"] == created["id"]

    missing = test_client.get("/overnight/tasks/does-not-exist", headers=auth())
    assert missing.status_code == 404


def test_cancel_overnight_task_via_api(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)
    created = test_client.post(
        "/overnight/tasks",
        json={"objective": "Research something", "task_type": "research"},
        headers=auth(),
    ).json()

    cancelled = test_client.post(
        f"/overnight/tasks/{created['id']}/cancel",
        headers=auth(),
    )
    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "cancelled"

    conflict = test_client.post(
        f"/overnight/tasks/{created['id']}/cancel",
        headers=auth(),
    )
    assert conflict.status_code == 409


def test_cancel_missing_overnight_task_returns_404(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)
    response = test_client.post("/overnight/tasks/does-not-exist/cancel", headers=auth())
    assert response.status_code == 404


def test_list_overnight_tasks_filters_by_status_via_api(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)
    created = test_client.post(
        "/overnight/tasks",
        json={"objective": "Research something", "task_type": "research"},
        headers=auth(),
    ).json()
    test_client.post(f"/overnight/tasks/{created['id']}/cancel", headers=auth())
    test_client.post(
        "/overnight/tasks",
        json={"objective": "Still queued", "task_type": "research"},
        headers=auth(),
    )

    queued_only = test_client.get(
        "/overnight/tasks", params={"task_status": "queued"}, headers=auth()
    )
    assert queued_only.status_code == 200
    statuses = {item["status"] for item in queued_only.json()}
    assert statuses == {"queued"}
