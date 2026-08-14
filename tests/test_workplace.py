from __future__ import annotations

import json
from pathlib import Path

import httpx
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.workplace import (
    BrowserSandbox,
    BrowserSandboxError,
    agent_visual_for,
    parse_allowed_domains,
)

TOKEN = "workplace-test-token"


def make_client(tmp_path: Path) -> TestClient:
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
        dream_team_sandbox_path=tmp_path / "sandbox",
        dream_team_active_path=tmp_path / "active",
        browser_sandbox_screenshot_path=tmp_path / "screenshots",
    )
    return TestClient(create_app(settings))


def auth() -> dict[str, str]:
    return {"Authorization": f"Bearer {TOKEN}"}


def test_workplace_is_served_and_redirected(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    redirect = client.get("/workplace", follow_redirects=False)
    page = client.get("/workplace/assets/index.html")
    assert redirect.status_code == 307
    assert redirect.headers["location"] == "/workplace/assets/index.html"
    assert page.status_code == 200
    assert "NOBS Workplace" in page.text


def test_workplace_status_empty_floor(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    response = client.get("/workplace/status")
    assert response.status_code == 200
    payload = response.json()
    assert payload["agents"] == []
    assert len(payload["stations"]) >= 5
    assert "allowlisted" in payload["browser_sandbox"]["security"].lower()


def test_workplace_shows_running_dream_team_agents(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    session = client.post(
        "/dream-team/sessions",
        headers=auth(),
        json={"objective": "Plan the week", "context": "personal"},
    ).json()
    client.app.state.agent_store.create_dream_team_draft(
        session_id=session["id"],
        name="Planner",
        role="Scheduling",
        persona={"tone": "warm", "specialty": "plans"},
    )
    client.app.state.agent_store.update_dream_team_session(session["id"], "running")

    payload = client.get("/workplace/status").json()
    assert len(payload["agents"]) == 1
    agent = payload["agents"][0]
    assert agent["name"] == "Planner"
    assert agent["icon"]
    assert agent["color"].startswith("#")
    assert agent["source"] == "dream_team"
    assert payload["dream_team"]["id"] == session["id"]


def test_workplace_shows_approved_active_agents(tmp_path: Path) -> None:
    active = tmp_path / "active"
    active.mkdir(parents=True)
    (active / "planner.json").write_text(
        json.dumps({"name": "Planner", "role": "Daily planning"}),
        encoding="utf-8",
    )
    client = make_client(tmp_path)
    payload = client.get("/workplace/status").json()
    assert any(agent["name"] == "Planner" and agent["source"] == "approved" for agent in payload["agents"])


def test_browser_sandbox_blocks_disallowed_domain(tmp_path: Path) -> None:
    sandbox = BrowserSandbox(allowed_domains=parse_allowed_domains("wikipedia.org"))
    try:
        sandbox.create_session("agent-1", "https://example.com")
        raise AssertionError("expected BrowserSandboxError")
    except BrowserSandboxError as error:
        assert "not allowed" in str(error).lower()


def test_browser_sandbox_allows_listed_domain(tmp_path: Path) -> None:
    sandbox = BrowserSandbox(
        allowed_domains=parse_allowed_domains("wikipedia.org"),
        screenshot_dir=tmp_path / "shots",
    )
    session = sandbox.create_session("agent-1", "https://en.wikipedia.org/wiki/Main_Page")
    assert session["url"].startswith("https://")
    assert sandbox.screenshot_svg(session["id"]).startswith("<svg")


def test_browser_session_api_and_screenshot(tmp_path: Path) -> None:
    client = make_client(tmp_path)

    blocked = client.post(
        "/workplace/browser/sessions",
        headers=auth(),
        json={"agent_id": "agent-1", "url": "https://example.com"},
    )
    assert blocked.status_code == 400

    created = client.post(
        "/workplace/browser/sessions",
        headers=auth(),
        json={
            "agent_id": "agent-1",
            "url": "https://en.wikipedia.org/wiki/Main_Page",
        },
    )
    assert created.status_code == 200
    session_id = created.json()["id"]

    transport = httpx.MockTransport(
        lambda _: httpx.Response(
            200,
            text="<html><title>Wikipedia Main Page</title></html>",
        )
    )
    client.app.state.workplace_browser.transport = transport
    screenshot = client.get(f"/workplace/browser/sessions/{session_id}/screenshot")
    assert screenshot.status_code == 200
    assert screenshot.headers["content-type"].startswith("image/svg+xml")
    assert "Wikipedia Main Page" in screenshot.text


def test_agent_visuals_are_stable() -> None:
    first = agent_visual_for("Planner", "Scheduling")
    second = agent_visual_for("Planner", "Scheduling")
    third = agent_visual_for("Researcher", "Research")
    assert first == second
    assert first != third
