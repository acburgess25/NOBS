from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app.agent_store import AgentStore
from app.config import Settings
from app.main import create_app
from app.tank_health import ready_from_checks
from app.tank_time import local_time_label
from app.url_safety import UnsafeURLError, assert_public_http_url


from zoneinfo import ZoneInfo


def test_local_time_label_uses_timezone() -> None:
    chicago_afternoon = datetime(2026, 7, 8, 13, 0, tzinfo=ZoneInfo("America/Chicago"))
    with patch("app.tank_time.local_now", return_value=chicago_afternoon):
        assert local_time_label("America/Chicago") == "13:00"


def test_assert_public_http_url_blocks_localhost() -> None:
    with pytest.raises(UnsafeURLError):
        assert_public_http_url("http://127.0.0.1/admin")


def test_assert_public_http_url_allows_public_host() -> None:
    assert_public_http_url("https://example.com/article")


def test_recover_stale_state_resets_executing_approvals(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    run_id = store.create_run("test", "personal")
    approval = store.create_approval(
        run_id=run_id,
        tool_name="write_workspace_note",
        arguments={"title": "x", "content": "y"},
        risk="change",
        reason="test",
    )
    store.claim_approval(approval["id"])
    old_time = (datetime.now(UTC) - timedelta(minutes=30)).isoformat()
    with store._lock:
        store._connect().execute(
            "UPDATE approvals SET created_at = ? WHERE id = ?",
            (old_time, approval["id"]),
        )
        store._connect().commit()

    result = store.recover_stale_state(approval_minutes=15, run_timeout_seconds=60)
    assert result["approvals_reset"] == 1
    recovered = store.get_approval(approval["id"])
    assert recovered["status"] == "pending"


def test_pairing_code_one_time_use(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    code = store.create_pairing_code(ttl_seconds=300)
    assert store.consume_pairing_code(code) is True
    assert store.consume_pairing_code(code) is False


def test_ready_from_checks_requires_ollama_and_database() -> None:
    ok, _ = ready_from_checks({"database": "ok", "ollama": "ok"})
    assert ok is True
    ok, message = ready_from_checks({"database": "ok", "ollama": "offline"})
    assert ok is False
    assert "offline" in message


def test_ready_endpoint_reports_dependency_status() -> None:
    settings = Settings(
        device_token="secret-token",
        agent_database_path=Path(":memory:"),
        agent_workspace_path=Path("/tmp/nobs-ready-test"),
    )

    def ollama_tags(_: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"models": [{"name": settings.ollama_model}]})

    app = create_app(settings)
    app.state.ollama_transport = httpx.MockTransport(ollama_tags)
    client = TestClient(app)
    headers = {"Authorization": "Bearer secret-token"}

    response = client.get("/ready", headers=headers)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ready"
    assert body["checks"]["database"] == "ok"
    assert body["checks"]["ollama"] == "ok"


def test_auth_pair_exchanges_dashboard_code() -> None:
    settings = Settings(
        device_token="secret-token",
        agent_database_path=Path(":memory:"),
        agent_workspace_path=Path("/tmp/nobs-pair-test"),
    )
    app = create_app(settings)
    store: AgentStore = app.state.agent_store
    code = store.create_pairing_code(ttl_seconds=300)
    client = TestClient(app)

    response = client.post("/auth/pair", json={"code": code})
    assert response.status_code == 200
    assert response.json()["device_token"] == "secret-token"
    assert client.post("/auth/pair", json={"code": code}).status_code == 401
