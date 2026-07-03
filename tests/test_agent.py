import json
from pathlib import Path

import httpx

from tests.test_chat import auth, client


def test_agent_executes_read_only_tool_without_approval(tmp_path: Path) -> None:
    calls = 0

    def ollama_response(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        payload = json.loads(request.content)
        assert payload["messages"][0]["content"].find("active context is business") >= 0
        if calls == 1:
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
        assert payload["messages"][-1]["role"] == "tool"
        return httpx.Response(
            200,
            json={"message": {"role": "assistant", "content": "Tank is healthy."}},
        )

    response = client(httpx.MockTransport(ollama_response), tmp_path).post(
        "/agent/tasks",
        json={"objective": "Check Tank", "context": "business"},
        headers=auth(),
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "completed"
    assert payload["message"] == "Tank is healthy."
    assert payload["approvals"] == []
    assert payload["tool_results"][0]["tool"] == "get_tank_status"


def test_agent_queues_change_until_user_approves(tmp_path: Path) -> None:
    calls = 0

    def ollama_response(_: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            return httpx.Response(
                200,
                json={
                    "message": {
                        "role": "assistant",
                        "content": "",
                        "tool_calls": [
                            {
                                "type": "function",
                                "function": {
                                    "name": "write_workspace_note",
                                    "arguments": {
                                        "context": "personal",
                                        "title": "Weekly priorities",
                                        "content": "Protect Friday afternoon for planning.",
                                    },
                                },
                            }
                        ],
                    }
                },
            )
        return httpx.Response(
            200,
            json={
                "message": {
                    "role": "assistant",
                    "content": "I prepared the note and need your approval.",
                }
            },
        )

    test_client = client(httpx.MockTransport(ollama_response), tmp_path)
    task = test_client.post(
        "/agent/tasks",
        json={"objective": "Save my weekly priority", "context": "personal"},
        headers=auth(),
    )

    assert task.status_code == 200
    task_payload = task.json()
    assert task_payload["status"] == "awaiting_approval"
    assert not (tmp_path / "personal" / "weekly-priorities.md").exists()
    approval_id = task_payload["approvals"][0]["id"]

    pending = test_client.get("/agent/approvals", headers=auth())
    assert [item["id"] for item in pending.json()] == [approval_id]

    approved = test_client.post(
        f"/agent/approvals/{approval_id}",
        json={"decision": "approve"},
        headers=auth(),
    )

    assert approved.status_code == 200
    assert approved.json()["status"] == "approved"
    note = tmp_path / "personal" / "weekly-priorities.md"
    assert note.read_text() == (
        "# Weekly priorities\n\nProtect Friday afternoon for planning.\n"
    )


def test_denied_agent_action_never_changes_workspace(tmp_path: Path) -> None:
    def ollama_response(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        if payload["tools"]:
            return httpx.Response(
                200,
                json={
                    "message": {
                        "tool_calls": [
                            {
                                "function": {
                                    "name": "write_workspace_note",
                                    "arguments": {
                                        "context": "business",
                                        "title": "Do not save",
                                        "content": "This should never be written.",
                                    },
                                }
                            }
                        ]
                    }
                },
            )
        return httpx.Response(200, json={"message": {"content": "Waiting."}})

    test_client = client(httpx.MockTransport(ollama_response), tmp_path)
    task = test_client.post(
        "/agent/tasks",
        json={"objective": "Draft a note", "context": "business"},
        headers=auth(),
    ).json()
    approval_id = task["approvals"][0]["id"]

    denied = test_client.post(
        f"/agent/approvals/{approval_id}",
        json={"decision": "deny"},
        headers=auth(),
    )

    assert denied.status_code == 200
    assert denied.json()["status"] == "denied"
    assert not (tmp_path / "business" / "do-not-save.md").exists()


def test_agent_routes_require_device_authentication(tmp_path: Path) -> None:
    test_client = client(workspace=tmp_path)

    assert test_client.get("/agent/approvals").status_code == 401
    assert test_client.post(
        "/agent/tasks",
        json={"objective": "Check Tank"},
    ).status_code == 401


def test_approval_cannot_be_executed_twice(tmp_path: Path) -> None:
    def ollama_response(request: httpx.Request) -> httpx.Response:
        if json.loads(request.content)["tools"]:
            return httpx.Response(
                200,
                json={
                    "message": {
                        "tool_calls": [
                            {
                                "function": {
                                    "name": "write_workspace_note",
                                    "arguments": {
                                        "context": "shared",
                                        "title": "Once",
                                        "content": "Execute once.",
                                    },
                                }
                            }
                        ]
                    }
                },
            )
        return httpx.Response(200, json={"message": {"content": "Approve it."}})

    test_client = client(httpx.MockTransport(ollama_response), tmp_path)
    task = test_client.post(
        "/agent/tasks",
        json={"objective": "Write once", "context": "shared"},
        headers=auth(),
    ).json()
    approval_id = task["approvals"][0]["id"]
    endpoint = f"/agent/approvals/{approval_id}"

    assert test_client.post(endpoint, json={"decision": "approve"}, headers=auth()).status_code == 200
    assert test_client.post(endpoint, json={"decision": "approve"}, headers=auth()).status_code == 409
