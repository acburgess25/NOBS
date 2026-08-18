"""Tests for the Tank background optimizer."""

from __future__ import annotations

import asyncio
import json
from pathlib import Path
from unittest.mock import patch

import httpx

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings
from app.dream_team import DreamTeamSandbox
from app.tank_optimizer import (
    TankOptimizer,
    _is_user_facing_path,
    job_briefing_index_light,
    job_model_ping,
    job_model_warmup,
)
from tests.test_chat import auth, client


def _all_route_paths(app) -> list[str]:
    """Every path the app serves, including routes behind included routers.

    Routes used to hang directly off ``app.routes``, so this test could read
    ``route.path`` from each entry. Now that routes live in ``app/routes/``
    and arrive via ``include_router``, some entries are router wrappers whose
    real routes are nested one level down -- and the wrapper shape is a FastAPI
    implementation detail. Walking every shape keeps this test checking the
    live route table rather than a FastAPI version.
    """
    paths: list[str] = []

    def walk(routes) -> None:
        for route in routes:
            path = getattr(route, "path", None)
            if path is not None:
                paths.append(path)
                continue
            nested = getattr(route, "original_router", None)
            nested_routes = getattr(nested, "routes", None) or getattr(route, "routes", None)
            if nested_routes:
                walk(nested_routes)

    walk(app.routes)
    return paths


def test_optimizer_idle_requires_quiet_api_and_low_cpu() -> None:
    optimizer = TankOptimizer(Settings(optimizer_min_idle_seconds=60))
    with patch.object(optimizer, "cpu_percent", return_value=10.0):
        optimizer._last_api_activity = __import__("time").monotonic() - 120
        assert optimizer.is_idle() is True
    with patch.object(optimizer, "cpu_percent", return_value=90.0):
        optimizer._last_api_activity = __import__("time").monotonic() - 120
        assert optimizer.is_idle() is False
    with patch.object(optimizer, "cpu_percent", return_value=10.0):
        optimizer._last_api_activity = __import__("time").monotonic()
        assert optimizer.is_idle() is False


def test_record_api_activity_ignores_health_and_dashboard() -> None:
    optimizer = TankOptimizer(Settings())
    before = optimizer._last_api_activity
    optimizer.record_api_activity("/health")
    optimizer.record_api_activity("/dashboard/status")
    optimizer.record_api_activity("/optimizer/status")
    assert optimizer._last_api_activity == before
    optimizer.record_api_activity("/chat")
    assert optimizer._last_api_activity > before


def test_every_route_is_classified_for_optimizer_idle_tracking() -> None:
    """Walk the real route table instead of sample paths.

    The idle clock only resets for paths matching ``_USER_FACING_PREFIXES``,
    so a route family missing from that list keeps heavy background jobs
    running while a user is actively waiting on the API. Every route must
    either match a user-facing prefix or appear here as traffic that should
    not keep the Tank awake.
    """
    background = {
        "/health",
        "/dashboard",
        "/dashboard/status",
        "/dashboard/assets",
        # Pairing is kiosk-driven today. If open/close ever count as user
        # presence, move them into _USER_FACING_PREFIXES instead of here.
        "/dashboard/pairing",
        "/dashboard/pairing/open",
        "/dashboard/pairing/close",
        "/optimizer/status",
        "/optimizer/run-now",
        "/tank/optimizer",
        "/workplace",
        "/workplace/status",
        "/workplace/assets",
        "/openapi.json",
        "/docs",
        "/docs/oauth2-redirect",
        "/redoc",
    }
    served = _all_route_paths(client().app)
    # Guard the walker itself: if it silently stopped finding routes, the
    # assertion below would pass while checking nothing.
    assert "/chat" in served
    unclassified = sorted(
        path for path in served if not _is_user_facing_path(path) and path not in background
    )
    assert unclassified == []


def test_optimizer_status_payload() -> None:
    optimizer = TankOptimizer(Settings(optimizer_intensity="heavy"))
    payload = optimizer.status()
    assert payload["enabled"] is True
    assert payload["intensity"] == "heavy"
    assert "dream_team_batch" in payload["job_types"]["heavy"]
    assert payload["next_heavy_job_type"] in payload["job_types"]["heavy"]


def test_job_briefing_index_light_persists_index() -> None:
    store = AgentStore(Path(":memory:"))
    store.sync_calendar(
        [{"title": "Standup", "start": "09:00", "end": "09:30", "context": "business"}]
    )
    result = asyncio.run(job_briefing_index_light(store))
    assert result["index"]["calendar_count"] == 1
    stored = json.loads(store.get_kv("optimizer_briefing_index") or "{}")
    assert stored["calendar_count"] == 1


def test_job_model_ping_with_mock_transport() -> None:
    def ollama_response(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"models": [{"name": "qwen3:8b"}]})

    settings = Settings(ollama_model="qwen3:8b")
    result = asyncio.run(job_model_ping(settings, httpx.MockTransport(ollama_response)))
    assert "available" in result["summary"]


def test_job_model_warmup_with_mock_transport() -> None:
    def ollama_response(request: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={"message": {"content": json.dumps({"status": "ok", "service": "nobs-tank"})}},
        )

    settings = Settings()
    result = asyncio.run(job_model_warmup(settings, httpx.MockTransport(ollama_response)))
    assert result["response"]["status"] == "ok"
    assert "passed" in result["summary"]


def test_optimizer_status_endpoint_is_public(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)
    response = test_client.get("/optimizer/status")
    assert response.status_code == 200
    assert response.json()["enabled"] is True


def test_optimizer_run_now_requires_auth(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)
    assert test_client.post("/optimizer/run-now").status_code == 401


def test_optimizer_run_now_executes_model_ping(tmp_path: Path) -> None:
    def ollama_response(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/api/tags"):
            return httpx.Response(200, json={"models": [{"name": "qwen3:8b"}]})
        return httpx.Response(
            200,
            json={"message": {"content": json.dumps({"status": "ok", "service": "nobs-tank"})}},
        )

    test_client = client(httpx.MockTransport(ollama_response), workspace=tmp_path)
    response = test_client.post(
        "/optimizer/run-now",
        params={"job_type": "model_ping"},
        headers=auth(),
    )
    assert response.status_code == 200
    assert response.json()["job_type"] == "model_ping"
    assert response.json()["success"] is True


def test_dashboard_status_includes_optimizer(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)
    response = test_client.get("/dashboard/status")
    assert response.status_code == 200
    assert "optimizer" in response.json()
    assert response.json()["optimizer"]["enabled"] is True


def test_optimizer_execute_job_model_ping(tmp_path: Path) -> None:
    from app.tank_optimizer import OptimizerJobKind

    settings = Settings(agent_workspace_path=tmp_path)
    store = AgentStore(Path(":memory:"))
    tools = ToolRegistry(tmp_path, store=store, settings=settings)
    optimizer = TankOptimizer(settings)

    def ollama_response(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"models": [{"name": settings.ollama_model}]})

    sandbox = DreamTeamSandbox(settings=settings, store=store, tools=tools)
    result = asyncio.run(
        optimizer._execute_job(
            "model_ping",
            OptimizerJobKind.light,
            settings,
            store,
            tools,
            httpx.MockTransport(ollama_response),
            lambda: sandbox,
        )
    )
    assert result.success is True
    assert result.job_type == "model_ping"
