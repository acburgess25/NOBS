from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import httpx
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.research import ENTITLEMENT_KV_KEY, entitlement_denied_detail

TOKEN = "test-device-token"


def research_client(tmp_path: Path, **settings_overrides: object) -> TestClient:
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
        **settings_overrides,
    )
    return TestClient(create_app(settings))


def auth() -> dict[str, str]:
    return {"Authorization": f"Bearer {TOKEN}"}


def test_research_routes_require_authentication(tmp_path: Path) -> None:
    client = research_client(tmp_path)

    assert client.get("/research").status_code == 401
    assert client.post("/research", json={"topic": "AI news"}).status_code == 401
    assert client.get("/research/job-id").status_code == 401


def test_research_denied_without_entitlement_in_production(tmp_path: Path) -> None:
    client = research_client(tmp_path, environment="production")

    response = client.post(
        "/research",
        json={"topic": "Local EV incentives"},
        headers=auth(),
    )

    assert response.status_code == 403
    assert response.json()["detail"] == entitlement_denied_detail()


def test_research_allowed_with_entitlement_in_production(tmp_path: Path) -> None:
    calls = 0

    def ollama_response(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        payload = json.loads(request.content)
        if calls == 1:
            return httpx.Response(
                200,
                json={
                    "message": {
                        "tool_calls": [
                            {
                                "function": {
                                    "name": "web_search",
                                    "arguments": {"query": "EV incentives", "max_results": 3},
                                }
                            }
                        ]
                    }
                },
            )
        assert payload["messages"][-1]["role"] == "tool"
        return httpx.Response(
            200,
            json={
                "message": {
                    "content": (
                        "Federal credits remain available for qualifying EV purchases. "
                        "Sources: Example Incentives Guide."
                    )
                }
            },
        )

    client = research_client(tmp_path, environment="production")
    client.app.state.agent_store.set_kv(ENTITLEMENT_KV_KEY, "true")
    client.app.state.ollama_transport = httpx.MockTransport(ollama_response)

    with patch("app.agent_tools.DDGS") as mock_ddgs:
        mock_ddgs.return_value.text.return_value = [
            {
                "title": "Example Incentives Guide",
                "href": "https://example.com/incentives",
                "body": "Summary text",
            }
        ]
        response = client.post(
            "/research",
            json={"topic": "Local EV incentives", "context": "personal"},
            headers=auth(),
        )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "completed"
    assert "Federal credits" in body["summary"]
    assert len(body["sources"]) == 1
    assert body["sources"][0]["url"] == "https://example.com/incentives"
    assert body["topic"] == "Local EV incentives"


def test_list_and_get_research_jobs(tmp_path: Path) -> None:
    client = research_client(tmp_path)
    store = client.app.state.agent_store
    created = store.create_research_job("Morning news", "shared")
    store.update_research_job(
        created["id"],
        status="completed",
        summary="Three headlines worth knowing.",
        sources=[{"title": "Headline", "url": "https://example.com", "kind": "news_feed"}],
        run_id="run-123",
    )

    listed = client.get("/research", headers=auth())
    assert listed.status_code == 200
    jobs = listed.json()
    assert len(jobs) == 1
    assert jobs[0]["summary"] == "Three headlines worth knowing."

    fetched = client.get(f"/research/{created['id']}", headers=auth())
    assert fetched.status_code == 200
    assert fetched.json()["id"] == created["id"]


def test_get_research_job_returns_404_for_missing_job(tmp_path: Path) -> None:
    client = research_client(tmp_path)

    response = client.get("/research/missing", headers=auth())

    assert response.status_code == 404
    assert response.json()["detail"] == "Research job not found"
