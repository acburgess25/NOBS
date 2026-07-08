from __future__ import annotations

from pathlib import Path

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

TOKEN = "test-device-token"


def memories_client(tmp_path: Path) -> TestClient:
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    return TestClient(create_app(settings))


def auth() -> dict[str, str]:
    return {"Authorization": f"Bearer {TOKEN}"}


def test_memories_routes_require_authentication(tmp_path: Path) -> None:
    client = memories_client(tmp_path)

    assert client.get("/memories").status_code == 401
    assert client.patch("/memories/missing", json={"content": "updated"}).status_code == 401
    assert client.delete("/memories/missing").status_code == 401


def test_list_memories_starts_empty(tmp_path: Path) -> None:
    client = memories_client(tmp_path)

    response = client.get("/memories", headers=auth())

    assert response.status_code == 200
    assert response.json() == []


def test_create_list_update_and_delete_memory_via_store(tmp_path: Path) -> None:
    client = memories_client(tmp_path)
    store = client.app.state.agent_store
    created = store.create_memory("I prefer tea in the morning", "preference", "user_explicit")

    listed = client.get("/memories", headers=auth())
    assert listed.status_code == 200
    memories = listed.json()
    assert len(memories) == 1
    assert memories[0]["id"] == created["id"]
    assert memories[0]["content"] == "I prefer tea in the morning"
    assert memories[0]["category"] == "preference"
    assert memories[0]["source"] == "user_explicit"

    updated = client.patch(
        f"/memories/{created['id']}",
        json={"content": "I prefer coffee in the morning", "category": "habit"},
        headers=auth(),
    )
    assert updated.status_code == 200
    body = updated.json()
    assert body["content"] == "I prefer coffee in the morning"
    assert body["category"] == "habit"

    deleted = client.delete(f"/memories/{created['id']}", headers=auth())
    assert deleted.status_code == 200
    assert deleted.json() == {"status": "deleted"}
    assert client.get("/memories", headers=auth()).json() == []


def test_update_memory_returns_404_for_missing_memory(tmp_path: Path) -> None:
    client = memories_client(tmp_path)

    response = client.patch(
        "/memories/does-not-exist",
        json={"content": "new value"},
        headers=auth(),
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "Memory not found"


def test_delete_memory_returns_404_for_missing_memory(tmp_path: Path) -> None:
    client = memories_client(tmp_path)

    response = client.delete("/memories/does-not-exist", headers=auth())

    assert response.status_code == 404
    assert response.json()["detail"] == "Memory not found"


def test_update_memory_rejects_invalid_category(tmp_path: Path) -> None:
    client = memories_client(tmp_path)
    store = client.app.state.agent_store
    created = store.create_memory("Standup at 9", "schedule", "chat")

    response = client.patch(
        f"/memories/{created['id']}",
        json={"category": "invalid"},
        headers=auth(),
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Invalid memory category"


def test_chat_remember_creates_memory_and_updates_receipt(tmp_path: Path) -> None:
    import httpx

    def ollama_response(_: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"message": {"content": "Sure."}})

    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    app = create_app(settings)
    app.state.ollama_transport = httpx.MockTransport(ollama_response)
    client = TestClient(app)

    response = client.post(
        "/chat",
        json={"messages": [{"role": "user", "content": "Remember that I prefer quiet mornings"}]},
        headers=auth(),
    )

    assert response.status_code == 200
    body = response.json()
    assert "remember" in body["message"].lower()
    assert body["privacy_receipt"]["changed"] == ["Saved memory (preference)"]

    memories = client.get("/memories", headers=auth()).json()
    assert len(memories) == 1
    assert memories[0]["content"] == "I prefer quiet mornings"
    assert memories[0]["source"] == "user_explicit"


def test_chat_forget_deletes_matching_memory(tmp_path: Path) -> None:
    import httpx

    def ollama_response(_: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"message": {"content": "Okay."}})

    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    app = create_app(settings)
    app.state.ollama_transport = httpx.MockTransport(ollama_response)
    client = TestClient(app)
    store = app.state.agent_store
    store.create_memory("I prefer quiet mornings", "preference", "user_explicit")

    response = client.post(
        "/chat",
        json={"messages": [{"role": "user", "content": "Forget that quiet mornings"}]},
        headers=auth(),
    )

    assert response.status_code == 200
    assert response.json()["privacy_receipt"]["changed"] == ["Deleted 1 memory"]
    assert client.get("/memories", headers=auth()).json() == []
