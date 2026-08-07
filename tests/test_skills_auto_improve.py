"""Tests for the NOBS skills layer and end-of-run auto-improvement."""

import json
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings
from app.main import create_app

from tests.test_chat import TOKEN, auth


def _auto_improve_client(
    transport: httpx.BaseTransport,
    tmp_path: Path,
) -> TestClient:
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
        agent_project_path=tmp_path,
        # Feature explicitly enabled for the auto-improve flow test.
        auto_improve_enabled=True,
    )
    app = create_app(settings)
    app.state.ollama_transport = transport
    return TestClient(app)


# --------------------------------------------------------------------------- #
# Store layer                                                                 #
# --------------------------------------------------------------------------- #


def test_skill_crud_and_insights(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")

    assert store.list_skills() == []
    assert store._active_skills() == []

    skill = store.create_skill(
        "Weekly Review",
        "Run a weekly plan review against the calendar.",
        "1. List goals\n2. Check calendar\n3. Remind about gaps.",
        tags=["planning", "weekly"],
        status="active",
        source="auto",
        run_id="run-1",
    )
    assert skill["status"] == "active"
    assert skill["tags"] == ["planning", "weekly"]
    assert store.get_skill_by_name("weekly review")["id"] == skill["id"]

    # update fields
    updated = store.update_skill(skill["id"], status="retired", tags=["archive"])
    assert updated["status"] == "retired"
    assert updated["tags"] == ["archive"]

    # usage tracking
    store.record_skill_usage(skill["id"])
    assert store.get_skill(skill["id"])["usage_count"] == 1

    # insights
    insight = store.record_insight(
        "run-1",
        "User prefers short replies.",
        kind="recommendation",
        detail={"tools_used": ["web_search"]},
    )
    assert insight["kind"] == "recommendation"
    assert insight["detail"]["tools_used"] == ["web_search"]
    assert [i["insight"] for i in store.list_insights()] == [
        "User prefers short replies."
    ]


def test_skill_tools(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "agent.db")
    tools = ToolRegistry(tmp_path / "workspace", store=store)

    # list is empty initially
    listed = tools.execute("list_skills", {})
    assert listed["skills"] == []

    # create skill via tool
    created = tools.execute(
        "create_skill",
        {
            "name": "Concise Replies",
            "description": "Prefer short, direct answers.",
            "instructions": "1. Be concise.\n2. No preamble.",
            "tags": ["tone"],
        },
    )
    assert created["status"] == "success"
    skill_id = created["skill_id"]

    # it is stored as draft (won't influence runs until activated)
    assert store.get_skill(skill_id)["status"] == "draft"

    # read skill by name marks usage
    read = tools.execute("read_skill", {"skill": "concise replies"})
    assert read["skill"]["name"] == "Concise Replies"
    assert store.get_skill(skill_id)["usage_count"] == 1

    # list now shows the skill
    assert tools.execute("list_skills", {})["skills"][0]["name"] == "Concise Replies"

    # missing required fields raises
    with pytest.raises(ValueError, match="required"):
        tools.execute("create_skill", {"name": "", "description": "", "instructions": ""})


# --------------------------------------------------------------------------- #
# System prompt injection                                                     #
# --------------------------------------------------------------------------- #


def test_active_skills_injected_into_system_prompt(tmp_path: Path) -> None:
    from app.agent import TankAgent
    from app.config import Settings

    store = AgentStore(tmp_path / "agent.db")
    store.create_skill(
        "Voice Style",
        "Match the user's concise tone.",
        "Keep replies under 2 sentences.",
        status="active",
    )
    # Inactive/draft skills must not leak into the prompt.
    store.create_skill(
        "Proto Skill",
        "Not yet approved.",
        "Do nothing yet.",
        status="draft",
    )

    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
        agent_project_path=tmp_path,
        auto_improve_enabled=False,
    )
    prompt = TankAgent(settings, store, ToolRegistry(tmp_path / "workspace", store=store))._system_prompt(
        "personal", "assistant"
    )
    assert "Voice Style" in prompt
    assert "Keep replies under 2 sentences" in prompt
    assert "Proto Skill" not in prompt


# --------------------------------------------------------------------------- #
# Auto-improve reflection flow                                                #
# --------------------------------------------------------------------------- #


def test_auto_improve_distills_skill_and_surface_it(tmp_path: Path) -> None:
    calls = 0

    def ollama_response(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        payload = json.loads(request.content)
        if calls == 1:
            # main loop: read-only tool call
            assert "tools" in payload
            return httpx.Response(
                200,
                json={
                    "message": {
                        "role": "assistant",
                        "content": "",
                        "tool_calls": [
                            {
                                "type": "function",
                                "function": {"name": "get_tank_status", "arguments": {}},
                            }
                        ],
                    }
                },
            )
        if calls == 2:
            # main loop: final assistant reply (completed)
            assert "tools" in payload
            return httpx.Response(
                200,
                json={"message": {"role": "assistant", "content": "Tank is healthy."}},
            )
        # calls == 3: reflection pass — plain chat, no tools
        assert "tools" not in payload
        assert payload["messages"][0]["role"] == "system"
        assert "self-improvement" in payload["messages"][0]["content"]
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "message": {
                            "role": "assistant",
                            "content": json.dumps(
                                {
                                    "insight": "User checks Tank health often.",
                                    "skill": {
                                        "name": "Health Check",
                                        "description": "Run get_tank_status and summarize storage.",
                                        "instructions": (
                                            "1. Call get_tank_status.\n2. Summarize disk and load."
                                        ),
                                        "tags": ["ops", "health"],
                                    },
                                }
                            ),
                        }
                    }
                ]
            },
        )

    client = _auto_improve_client(httpx.MockTransport(ollama_response), tmp_path)
    task = client.post(
        "/agent/tasks",
        json={"objective": "Check Tank health", "context": "personal"},
        headers=auth(),
    )
    assert task.status_code == 200
    assert task.json()["status"] == "completed"
    assert calls == 3  # main loop (2) + reflection (1)

    store = AgentStore(tmp_path / "agent.db")
    # durable insight recorded
    insights = store.list_insights()
    assert len(insights) == 1
    assert insights[0]["kind"] == "recommendation"
    assert "health" in insights[0]["insight"].lower()

    # draft skill created (auto, draft)
    draft = store.get_skill_by_name("Health Check")
    assert draft is not None
    assert draft["status"] == "draft"
    assert draft["source"] == "auto"
    assert draft["run_id"] is not None

    # surfaced as a user-facing proposal
    props = store.list_proposals()
    assert len(props) == 1
    assert props[0]["title"] == "Suggested skill: Health Check"


def test_auto_improve_skips_trivial_runs(tmp_path: Path) -> None:
    calls = 0

    def ollama_response(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            return httpx.Response(
                200,
                json={"message": {"role": "assistant", "content": "hi"}},
            )
        pytest.fail("Reflection should not fire for trivial runs")

    client = _auto_improve_client(httpx.MockTransport(ollama_response), tmp_path)
    task = client.post(
        "/agent/tasks",
        json={"objective": "hi", "context": "personal"},
        headers=auth(),
    )
    assert task.json()["status"] == "completed"
    assert calls == 1  # no tool results, short reply -> no reflection

    store = AgentStore(tmp_path / "agent.db")
    assert store.list_insights() == []
    assert store.list_skills() == []
    assert store.list_proposals() == []