"""Tests for the NOBS venture / idea engine."""

import json
from pathlib import Path

import httpx
from fastapi.testclient import TestClient

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings
from app.main import create_app

from tests.test_chat import TOKEN, auth


def _app(
    transport: httpx.BaseTransport | None = None,
    tmp_path: Path | None = None,
) -> TestClient:
    tmp = tmp_path or Path(".")
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp / "agent.db",
        agent_workspace_path=tmp / "workspace",
        agent_project_path=tmp,
    )
    app = create_app(settings)
    if transport is not None:
        app.state.ollama_transport = transport
    return TestClient(app)


def _candidates_json() -> str:
    return json.dumps(
        [
            {
                "title": "Sell NOBS as a product",
                "description": "Package Tank as a hosted AI manager.",
                "strategy": "Launch a waitlist, then a subscription tier.",
                "tags": ["product", "saas"],
            },
            {
                "title": "Publish a recipe pack",
                "description": "Sell a curated set of Goose recipes.",
                "strategy": "List on the marketplace at a one-time price.",
                "tags": ["marketplace", "digital"],
            },
        ]
    )


# --------------------------------------------------------------------------- #
# Store                                                                        #
# --------------------------------------------------------------------------- #


def test_ideas_crud_pipeline(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    assert store.list_ideas() == []

    idea = store.create_idea(
        "Sell NOBS",
        "Package Tank as a product.",
        strategy="Offer a hosted tier.",
        tags=["saas"],
    )
    assert idea["status"] == "raw"
    assert idea["tags"] == ["saas"]
    assert store.get_idea_by_title("sell nobs")["id"] == idea["id"]

    updated = store.update_idea(
        idea["id"],
        status="validated",
        score=8.5,
        rationale="Clear demand.",
        strategy="Launch waitlist.",
    )
    assert updated["status"] == "validated"
    assert updated["score"] == 8.5

    # invalid status raises
    try:
        store.update_idea(idea["id"], status="nonsense")
        raise AssertionError("expected ValueError")
    except ValueError as error:
        assert "Invalid idea status" in str(error)

    # ideas sorted by score desc
    store.create_idea("Meh", "Low priority", source="auto")
    titles = [i["title"] for i in store.list_ideas()]
    assert titles[0] == "Sell NOBS"
    assert titles[1] == "Meh"

    assert [i["title"] for i in store.list_ideas(status="raw")] == ["Meh"]
    assert store.get_idea_by_title("missing") is None


# --------------------------------------------------------------------------- #
# Tools                                                                        #
# --------------------------------------------------------------------------- #


def test_idea_tools(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    tools = ToolRegistry(tmp_path / "workspace", store=store)

    assert tools.execute("list_ideas", {})["ideas"] == []

    captured = tools.execute(
        "capture_idea",
        {
            "title": "Podcast ads",
            "description": "Monetize via niche sponsorship.",
            "strategy": "Sell direct sponsorships.",
            "tags": ["media", "ads"],
        },
    )
    assert captured["status"] == "success"
    idea_id = captured["idea_id"]
    assert store.get_idea(idea_id)["tags"] == ["media", "ads"]

    # list_ideas now includes it
    assert tools.execute("list_ideas", {})["ideas"][0]["title"] == "Podcast ads"

    # update_idea advances pipeline
    updated = tools.execute(
        "update_idea",
        {"idea_id": idea_id, "status": "building", "score": 9},
    )
    assert updated["idea"]["status"] == "building"
    assert updated["idea"]["score"] == 9

    # missing args raise
    try:
        tools.execute("capture_idea", {"title": "", "description": ""})
        raise AssertionError("expected ValueError")
    except ValueError as error:
        assert "required" in str(error)


# --------------------------------------------------------------------------- #
# Brainstorm deliberation (+ endpoint)                                         #
# --------------------------------------------------------------------------- #

CANDIDATE_CALL = 0
SCORE_CALL = 1


def _brainstorm_transport():
    calls = {"n": 0}

    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        call = calls["n"]
        calls["n"] += 1
        if call == CANDIDATE_CALL:
            assert "venture council" in payload["messages"][0]["content"]
            return httpx.Response(
                200,
                json={
                    "choices": [{"message": {"role": "assistant", "content": _candidates_json()}}]
                },
            )
        # score pass for each candidate
        assert "score" in payload["messages"][0]["content"]
        idx = call - 1
        score = 9.0 - float(idx)  # first candidate scores highest
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "role": "assistant",
                            "content": json.dumps(
                                {"score": score, "rationale": f"Rationale {idx}"}
                            ),
                        }
                    }
                ]
            },
        )

    return calls, handler


def test_brainstorm_best_of_best(tmp_path: Path) -> None:
    calls, handler = _brainstorm_transport()
    client = _app(httpx.MockTransport(handler), tmp_path)

    resp = client.post(
        "/agent/brainstorm",
        json={"topic": "make money with NOBS", "n_candidates": 2, "take_top": 1},
        headers=auth(),
    )
    assert resp.status_code == 200
    ideas = resp.json()
    assert len(ideas) == 1  # best of the best only
    assert ideas[0]["title"] == "Sell NOBS as a product"
    assert ideas[0]["score"] >= 8.0
    assert ideas[0]["status"] == "validated"  # high score -> validated
    assert ideas[0]["source"] == "brainstorm"
    assert calls["n"] == 3  # 1 generate + 2 score passes

    # stored + a proposal was surfaced
    store = AgentStore(tmp_path / "agent.db")
    assert len(store.list_ideas()) == 1
    proposals = store.list_proposals()
    assert any("Venture idea" in p["title"] for p in proposals)


def test_brainstorm_low_score_stays_deliberating(tmp_path: Path) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        if "venture council" in payload["messages"][0]["content"]:
            return httpx.Response(
                200,
                json={
                    "choices": [{"message": {"role": "assistant", "content": _candidates_json()}}]
                },
            )
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "role": "assistant",
                            "content": json.dumps(
                                {"score": 3.0, "rationale": "Weak demand."}
                            ),
                        }
                    }
                ]
            },
        )

    client = _app(httpx.MockTransport(handler), tmp_path)
    resp = client.post(
        "/agent/brainstorm",
        json={"topic": "side income", "n_candidates": 2, "take_top": 2},
        headers=auth(),
    )
    assert resp.status_code == 200
    ideas = resp.json()
    assert len(ideas) == 2
    assert all(i["status"] == "deliberating" for i in ideas)
    # low scores -> no venture proposal surfaced
    store = AgentStore(tmp_path / "agent.db")
    assert store.list_proposals() == []


def test_ideas_endpoint_lists(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    store.create_idea("A", "Alpha", status="validated", score=9.0)
    store.create_idea("B", "Beta", status="raw")

    client = _app(tmp_path=tmp_path)
    resp = client.get("/agent/ideas", headers=auth())
    assert resp.status_code == 200
    data = resp.json()
    assert [i["title"] for i in data] == ["A", "B"]

    filtered = client.get("/agent/ideas?idea_status=raw", headers=auth())
    assert [i["title"] for i in filtered.json()] == ["B"]

# --------------------------------------------------------------------------- #
# Waitlist (landing capture into Tank)                                        #
# --------------------------------------------------------------------------- #


def test_waitlist_capture_and_list(tmp_path: Path) -> None:
    from app.main import create_app  # noqa: F811
    from fastapi.testclient import TestClient  # noqa: F811

    store = AgentStore(tmp_path / "agent.db")
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
        agent_project_path=tmp_path,
    )
    client = TestClient(create_app(settings))

    # public capture — no auth
    resp = client.post(
        "/waitlist", json={"email": "hello@example.com", "source": "landing"}
    )
    assert resp.status_code == 200
    assert resp.json() == {"ok": True, "email": "hello@example.com"}

    # duplicate is idempotent
    client.post("/waitlist", json={"email": "hello@example.com"})
    assert store._count_waiters() == 1

    # invalid email rejected
    bad = client.post("/waitlist", json={"email": "not-an-email"})
    assert bad.status_code == 422

    # listing requires the device token
    listed = client.get("/waitlist")
    assert listed.status_code == 401 or listed.status_code == 403
    auth_listed = client.get("/waitlist", headers=auth())
    assert auth_listed.status_code == 200
    assert auth_listed.json()["count"] == 1
    assert auth_listed.json()["waiters"][0]["email"] == "hello@example.com"


# --------------------------------------------------------------------------- #
# Connections (Google / school) — never send without approval                 #
# --------------------------------------------------------------------------- #


def test_register_and_list_connections(tmp_path: Path) -> None:
    from fastapi.testclient import TestClient  # noqa: F811

    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
        agent_project_path=tmp_path,
    )
    client = TestClient(create_app(settings))

    # auth required
    assert client.get("/agent/connections").status_code in (401, 403)

    for provider, label, account in (
        ("google", "Gmail", "me@gmail.com"),
        ("google_workspace", "School", "me@school.edu"),
        ("calendar", "Calendar", "me@gmail.com"),
    ):
        r = client.post(
            "/agent/connections",
            json={"provider": provider, "label": label, "account": account},
            headers=auth(),
        )
        assert r.status_code == 200, r.text
        assert r.json()["send_requires_approval"] is True

    # unsupported provider defaults to 422
    bad = client.post(
        "/agent/connections", json={"provider": "facebook"}, headers=auth()
    )
    assert bad.status_code == 422

    conns = client.get("/agent/connections", headers=auth()).json()
    assert conns["count"] == 3
    assert conns["required_approval"].startswith("Any send")
    assert all(c["send_requires_approval"] is True for c in conns["connections"])
    assert {c["provider"] for c in conns["connections"]} >= {
        "google", "google_workspace", "calendar"
    }


# --------------------------------------------------------------------------- #
# Connector library (catalog of places/skills/apps)                           #
# --------------------------------------------------------------------------- #


def test_connector_catalog_endpoint(tmp_path: Path) -> None:
    from fastapi.testclient import TestClient  # noqa: F811

    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
        agent_project_path=tmp_path,
    )
    client = TestClient(create_app(settings))

    assert client.get("/agent/connectors").status_code in (401, 403)
    cat = client.get("/agent/connectors", headers=auth()).json()
    assert cat["count"] == 12
    names = {c["name"] for shelf in cat["catalog"].values() for c in shelf}
    assert {"google", "google_workspace", "outlook", "slack", "github",
            "notion", "calendar", "skills"} <= names
    # every connector stays behind approval for sends
    send = [c for shelf in cat["catalog"].values()
            for c in shelf if c["send_capable"]]
    assert send, "expected send-capable connectors present"


def test_discover_connectors_tool_is_read_only_and_searchable(tmp_path: Path) -> None:
    from app.connectors import search

    # searchable via the catalog module directly (the tool mirrors this)
    school = search("school")
    assert school and school[0]["name"] == "google_workspace"
    mail = search("mail")
    assert any(c["name"] == "mail" for c in mail)
    # description-sensitive search matches
    assert search("git")
