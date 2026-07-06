from __future__ import annotations

from pathlib import Path
import pytest
from fastapi.testclient import TestClient

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings
from app.main import create_app

TOKEN = "test-device-token"


def test_proposals_db_operations(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "test.db")

    # Empty list
    assert len(store.list_proposals()) == 0

    # Create proposal
    prop = store.create_proposal("Good Morning Routine", "Turn on coffee maker", "routine")
    assert prop["title"] == "Good Morning Routine"
    assert prop["proposal_type"] == "routine"
    assert prop["status"] == "pending"

    # List proposals
    assert len(store.list_proposals()) == 1
    assert len(store.list_proposals("pending")) == 1
    assert len(store.list_proposals("approved")) == 0

    # Decide proposal (approve)
    approved = store.decide_proposal(prop["id"], "approved")
    assert approved["status"] == "approved"
    assert approved["decided_at"] is not None

    # Decide already decided proposal raises error
    with pytest.raises(ValueError, match="missing or already decided"):
        store.decide_proposal(prop["id"], "approved")


def test_propose_idea_tool(tmp_path: Path) -> None:
    store = AgentStore(tmp_path / "test.db")
    tools = ToolRegistry(tmp_path / "workspace", store=store)

    # Missing fields raises error
    with pytest.raises(ValueError, match="required"):
        tools.execute("propose_idea", {"title": "", "description": "", "proposal_type": ""})

    # Execute successfully
    res = tools.execute(
        "propose_idea",
        {
            "title": "Optimize Heating",
            "description": "Lower temperature at night.",
            "proposal_type": "optimization",
        },
    )
    assert res["status"] == "success"
    assert res["proposal_id"] is not None

    # Verify saved in db
    proposals = store.list_proposals()
    assert len(proposals) == 1
    assert proposals[0]["title"] == "Optimize Heating"


def test_proposals_endpoints(tmp_path: Path) -> None:
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    app = create_app(settings)
    client = TestClient(app)
    auth = {"Authorization": f"Bearer {TOKEN}"}

    # Query empty proposals list
    response = client.get("/agent/proposals", headers=auth)
    assert response.status_code == 200
    assert response.json() == []

    # Propose an idea using the agent tools mock test setup
    store = app.state.agent_store
    prop = store.create_proposal("Coffee routine", "Turn on morning coffee", "routine")

    # Query proposals list
    response = client.get("/agent/proposals", headers=auth)
    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["id"] == prop["id"]

    # Decide proposal (approve)
    response = client.post(
        f"/agent/proposals/{prop['id']}/decide", json={"decision": "approve"}, headers=auth
    )
    assert response.status_code == 200
    assert response.json()["status"] == "approved"

    # Double decide fails
    response = client.post(
        f"/agent/proposals/{prop['id']}/decide", json={"decision": "dismiss"}, headers=auth
    )
    assert response.status_code == 409
