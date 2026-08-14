from __future__ import annotations

import json
from pathlib import Path

import httpx
from fastapi.testclient import TestClient

from app.agent_store import AgentStore
from app.config import Settings
from app.dream_team import DreamTeamSandbox, LocalFirstPolicy
from app.main import create_app

TOKEN = "test-device-token"


def _draft_ollama_response() -> dict:
    return {
        "message": {
            "content": json.dumps(
                {
                    "agents": [
                        {
                            "name": "Planner",
                            "role": "Daily planning",
                            "tone": "warm",
                            "specialty": "scheduling",
                            "suggested_tools": ["get_tank_status"],
                            "sample_objective": "Review today's priorities",
                        },
                        {
                            "name": "Researcher",
                            "role": "Local research",
                            "tone": "concise",
                            "specialty": "workspace notes",
                            "suggested_tools": ["list_workspace_files"],
                            "sample_objective": "List personal workspace files",
                        },
                    ]
                }
            )
        }
    }


def _sandbox_done_response() -> dict:
    return {
        "message": {
            "content": "I reviewed the sandbox objective and summarized next steps clearly.",
        }
    }


def make_client(tmp_path: Path, transport: httpx.MockTransport | None = None) -> TestClient:
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
        dream_team_sandbox_path=tmp_path / "sandbox",
        dream_team_active_path=tmp_path / "active",
        dream_team_max_agents=2,
        dream_team_max_iterations=1,
        dream_team_score_threshold=0.9,
    )
    app = create_app(settings)
    if transport is not None:
        app.state.ollama_transport = transport
    return TestClient(app)


def auth() -> dict[str, str]:
    return {"Authorization": f"Bearer {TOKEN}"}


def test_local_first_policy_documents_no_cloud() -> None:
    policy = LocalFirstPolicy()
    data = policy.as_dict()
    assert data["cloud_quota_used"] is False
    assert data["external_apis_in_loop"] is False
    assert "local" in data["inference"].lower()


def test_dream_team_store_roundtrip(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "test.db")
    session = store.create_dream_team_session(
        "Plan my week",
        "personal",
        {"local_first_policy": LocalFirstPolicy().as_dict()},
    )
    draft = store.create_dream_team_draft(
        session["id"],
        "Planner",
        "Planning",
        {"tone": "warm", "specialty": "scheduling", "system_prompt": "Be helpful"},
    )
    proposal = store.create_dream_team_proposal(
        session_id=session["id"],
        title="Dream team",
        summary="Two agents",
        members=[{"name": draft["name"], "role": draft["role"]}],
        metadata={"llm_calls": 3},
    )
    assert len(store.list_dream_team_sessions()) == 1
    assert len(store.list_dream_team_drafts(session["id"])) == 1
    approved = store.decide_dream_team_proposal(proposal["id"], "approved")
    assert approved["status"] == "approved"


def test_dream_team_policy_endpoint(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    response = client.get("/dream-team/policy", headers=auth())
    assert response.status_code == 200
    payload = response.json()
    assert payload["would_use_cloud_quota"] is False
    assert "web_search" in payload["external_tools_excluded_from_sandbox"]


def test_dream_team_session_run_and_proposal(tmp_path: Path) -> None:
    calls = 0

    def ollama_handler(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        payload = json.loads(request.content)
        messages = payload.get("messages", [])
        if payload.get("format") == "json" and calls == 1:
            return httpx.Response(200, json=_draft_ollama_response())
        if payload.get("format") == "json":
            return httpx.Response(
                200,
                json={
                    "message": {
                        "content": json.dumps(
                            {
                                "persona": {
                                    "tone": "direct",
                                    "specialty": "scheduling",
                                    "suggested_tools": ["get_tank_status"],
                                    "sample_objective": "Review priorities",
                                    "system_prompt": "You are Planner.",
                                }
                            }
                        )
                    }
                },
            )
        if any(m.get("role") == "tool" for m in messages):
            return httpx.Response(200, json=_sandbox_done_response())
        if payload.get("tools"):
            return httpx.Response(
                200,
                json={
                    "message": {
                        "tool_calls": [
                            {
                                "function": {
                                    "name": "get_tank_status",
                                    "arguments": {},
                                }
                            }
                        ]
                    }
                },
            )
        return httpx.Response(200, json=_sandbox_done_response())

    client = make_client(tmp_path, httpx.MockTransport(ollama_handler))

    create = client.post(
        "/dream-team/sessions",
        json={"objective": "Help me plan overloaded days", "context": "personal"},
        headers=auth(),
    )
    assert create.status_code == 200
    session_id = create.json()["id"]
    assert create.json()["config"]["local_first_policy"]["cloud_quota_used"] is False

    run = client.post(f"/dream-team/sessions/{session_id}/run", headers=auth())
    assert run.status_code == 200
    body = run.json()
    assert body["status"] == "proposed"
    assert len(body["drafts"]) == 2
    assert body["drafts"][0]["score"] is not None
    assert len(body["proposals"]) == 1
    assert body["proposals"][0]["metadata"]["llm_calls"] >= 1

    proposals = client.get("/dream-team/proposals", headers=auth())
    assert proposals.status_code == 200
    assert len(proposals.json()) == 1

    proposal_id = proposals.json()[0]["id"]
    approve = client.post(
        f"/dream-team/proposals/{proposal_id}/decide",
        json={"decision": "approve"},
        headers=auth(),
    )
    assert approve.status_code == 200
    assert approve.json()["active_manifests"] == 2
    assert (tmp_path / "active" / "planner.json").exists()


def test_dream_team_heuristic_score_without_extra_llm(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "score.db")
    settings = Settings(
        agent_database_path=tmp_path / "score.db",
        agent_workspace_path=tmp_path / "ws",
        dream_team_sandbox_path=tmp_path / "sandbox",
        dream_team_active_path=tmp_path / "active",
    )
    sandbox = DreamTeamSandbox(settings, store, tools=__import__("app.agent_tools", fromlist=["ToolRegistry"]).ToolRegistry(tmp_path / "ws"))
    draft = {
        "persona": {
            "tone": "warm",
            "specialty": "planning",
            "system_prompt": "Help",
            "sample_objective": "Plan day",
            "suggested_tools": ["get_tank_status"],
        },
        "test_result": {
            "response": "Here is a concise plan for your day with clear priorities.",
            "tool_results": [{"tool": "get_tank_status", "result": {"cpu_percent": 10}}],
        },
    }
    score = sandbox._heuristic_score(draft)
    assert score >= 0.6


def test_dream_team_reject_proposal(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "reject.db")
    session = store.create_dream_team_session("x", "personal", {})
    proposal = store.create_dream_team_proposal(
        session["id"], "Team", "summary", [], {}
    )
    settings = Settings(
        agent_database_path=tmp_path / "reject.db",
        agent_workspace_path=tmp_path / "ws",
        dream_team_sandbox_path=tmp_path / "sandbox",
        dream_team_active_path=tmp_path / "active",
    )
    sandbox = DreamTeamSandbox(
        settings,
        store,
        tools=__import__("app.agent_tools", fromlist=["ToolRegistry"]).ToolRegistry(tmp_path / "ws"),
    )
    result = sandbox.reject_proposal(proposal["id"])
    assert result["status"] == "rejected"


def test_dream_team_run_requires_queued_session(tmp_path: Path) -> None:
    client = make_client(tmp_path)
    store = AgentStore(tmp_path / "agent.db")
    session = store.create_dream_team_session("x", "personal", {})
    store.update_dream_team_session(session["id"], "proposed")
    response = client.post(f"/dream-team/sessions/{session['id']}/run", headers=auth())
    assert response.status_code == 409


def _sandbox_for(tmp_path: Path, sandbox_path: Path) -> DreamTeamSandbox:
    from app.agent_tools import ToolRegistry

    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "ws",
        dream_team_sandbox_path=sandbox_path,
        dream_team_active_path=tmp_path / "active",
    )
    store = AgentStore(tmp_path / "agent.db")
    return DreamTeamSandbox(settings, store, tools=ToolRegistry(tmp_path / "ws"))


def test_sandbox_dir_accepts_relative_root(tmp_path: Path, monkeypatch) -> None:
    """A relative sandbox root must still resolve to a usable directory.

    `dream_team_sandbox_path` defaults to the relative `data/dream-team-sandbox`,
    so a guard that compared the unresolved root against a resolved child
    rejected every valid session id in the default configuration.
    """
    monkeypatch.chdir(tmp_path)
    sandbox = _sandbox_for(tmp_path, Path("data/dream-team-sandbox"))

    path = sandbox._ensure_sandbox_dir("session-abc")

    assert path.is_dir()
    assert path.resolve() == (tmp_path / "data/dream-team-sandbox/session-abc").resolve()


def test_sandbox_dir_accepts_absolute_root(tmp_path: Path) -> None:
    sandbox = _sandbox_for(tmp_path, tmp_path / "sandbox")

    path = sandbox._ensure_sandbox_dir("session-abc")

    assert path.is_dir()
    assert path.resolve() == (tmp_path / "sandbox/session-abc").resolve()


def test_sandbox_dir_rejects_traversal(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.chdir(tmp_path)
    sandbox = _sandbox_for(tmp_path, Path("data/dream-team-sandbox"))

    for escape in ("../escape", "../../escape", "a/../../escape"):
        try:
            sandbox._ensure_sandbox_dir(escape)
        except ValueError as error:
            assert "escapes root" in str(error)
        else:
            raise AssertionError(f"traversal not rejected: {escape}")

    assert not (tmp_path / "escape").exists()
    assert not (tmp_path / "data/escape").exists()
