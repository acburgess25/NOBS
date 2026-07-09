"""Tests for the scene-based home control tools (list_home_scenes, run_home_scene).

Scenes are the safe, HomeKit-shaped way to trigger a whole-home routine from
chat: the tool can only target `scene.*` entities returned by
`list_home_scenes`, never an arbitrary accessory or service. See
docs/GOOGLE_HOME_INTEGRATION.md for the Home Assistant bridge pattern that
lets Apple Home/HomeKit scenes appear here.
"""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import httpx
import pytest
from pydantic import SecretStr

from app.agent_tools import ToolRegistry, ToolRisk
from app.home_assistant import HomeAssistantClient
from tests.test_chat import auth, client


def test_list_home_scenes_unconfigured(tmp_path: Path) -> None:
    client_ha = HomeAssistantClient("", None)
    tools = ToolRegistry(tmp_path, home_assistant=client_ha)

    res = tools.execute("list_home_scenes", {})
    assert "not configured" in res["error"]


def test_run_home_scene_unconfigured(tmp_path: Path) -> None:
    client_ha = HomeAssistantClient("", None)
    tools = ToolRegistry(tmp_path, home_assistant=client_ha)

    res = tools.execute("run_home_scene", {"entity_id": "scene.good_night"})
    assert "not configured" in res["error"]


def test_run_home_scene_is_change_risk() -> None:
    tools = ToolRegistry(Path("/tmp/nobs-test-workspace"))
    tool = tools.get("run_home_scene")
    assert tool is not None
    assert tool.risk is ToolRisk.CHANGE


def test_list_home_scenes_only_returns_scene_domain(tmp_path: Path) -> None:
    client_ha = HomeAssistantClient("http://hass.local", SecretStr("test-token"))
    tools = ToolRegistry(tmp_path, home_assistant=client_ha)

    mock_states = [
        {
            "entity_id": "scene.good_night",
            "state": "scening",
            "attributes": {"friendly_name": "Good Night"},
        },
        {
            "entity_id": "scene.movie_time",
            "state": "scening",
            "attributes": {"friendly_name": "Movie Time"},
        },
        {"entity_id": "light.living_room", "state": "on", "attributes": {}},
    ]

    with patch("httpx.Client") as mock_client_class:
        mock_client = MagicMock()
        mock_client_class.return_value.__enter__.return_value = mock_client
        mock_client.get.return_value = MagicMock(status_code=200, json=lambda: mock_states)

        res = tools.execute("list_home_scenes", {})

    assert res["truncated"] is False
    assert {scene["entity_id"] for scene in res["scenes"]} == {
        "scene.good_night",
        "scene.movie_time",
    }
    assert all(scene["domain"] == "scene" for scene in res["scenes"])


def test_run_home_scene_rejects_non_scene_entity(tmp_path: Path) -> None:
    client_ha = HomeAssistantClient("http://hass.local", SecretStr("test-token"))
    tools = ToolRegistry(tmp_path, home_assistant=client_ha)

    with pytest.raises(ValueError, match="only permitted to run scene entities"):
        tools.execute("run_home_scene", {"entity_id": "light.living_room"})

    with pytest.raises(ValueError, match="only permitted to run scene entities"):
        tools.execute("run_home_scene", {"entity_id": "lock.front_door"})


def test_run_home_scene_rejects_missing_entity_id(tmp_path: Path) -> None:
    client_ha = HomeAssistantClient("http://hass.local", SecretStr("test-token"))
    tools = ToolRegistry(tmp_path, home_assistant=client_ha)

    with pytest.raises(ValueError, match="entity_id is required"):
        tools.execute("run_home_scene", {"entity_id": ""})


def test_run_home_scene_calls_scene_turn_on(tmp_path: Path) -> None:
    client_ha = HomeAssistantClient("http://hass.local", SecretStr("test-token"))
    tools = ToolRegistry(tmp_path, home_assistant=client_ha)

    with patch("httpx.Client") as mock_client_class:
        mock_client = MagicMock()
        mock_client_class.return_value.__enter__.return_value = mock_client
        mock_client.post.return_value = MagicMock(status_code=200, json=lambda: {"context": "xyz"})

        res = tools.execute("run_home_scene", {"entity_id": "scene.good_night"})

    assert res["status"] == "success"
    mock_client.post.assert_called_with(
        "http://hass.local/api/services/scene/turn_on",
        headers={
            "Authorization": "Bearer test-token",
            "Content-Type": "application/json",
        },
        json={"entity_id": "scene.good_night"},
    )


def test_run_home_scene_http_error_returns_error_dict(tmp_path: Path) -> None:
    client_ha = HomeAssistantClient("http://hass.local", SecretStr("test-token"))
    tools = ToolRegistry(tmp_path, home_assistant=client_ha)

    with patch("httpx.Client") as mock_client_class:
        mock_client = MagicMock()
        mock_client_class.return_value.__enter__.return_value = mock_client
        mock_client.post.side_effect = httpx.ConnectError("connection refused")

        res = tools.execute("run_home_scene", {"entity_id": "scene.good_night"})

    assert "error" in res


# ------------------------------------------------------------------ #
# End-to-end through the agent + approval flow (safety guardrails)   #
# ------------------------------------------------------------------ #


def _scene_tool_call_response() -> httpx.Response:
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
                            "name": "run_home_scene",
                            "arguments": {"entity_id": "scene.good_night"},
                        },
                    }
                ],
            }
        },
    )


def test_run_home_scene_requires_approval_before_executing(tmp_path: Path) -> None:
    calls = 0

    def ollama_response(request: httpx.Request) -> httpx.Response:
        nonlocal calls
        calls += 1
        if calls == 1:
            return _scene_tool_call_response()
        return httpx.Response(
            200,
            json={"message": {"content": "Ready to run Good Night once you approve."}},
        )

    test_client = client(httpx.MockTransport(ollama_response), tmp_path)
    task = test_client.post(
        "/agent/tasks",
        json={"objective": "Run the good night scene", "context": "personal"},
        headers=auth(),
    )

    assert task.status_code == 200
    payload = task.json()
    assert payload["status"] == "awaiting_approval"
    assert payload["approvals"][0]["tool_name"] == "run_home_scene"
    assert payload["approvals"][0]["arguments"] == {"entity_id": "scene.good_night"}


def test_denied_scene_never_calls_home_assistant(tmp_path: Path) -> None:
    def ollama_response(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        if payload["tools"]:
            return _scene_tool_call_response()
        return httpx.Response(200, json={"message": {"content": "Waiting."}})

    test_client = client(httpx.MockTransport(ollama_response), tmp_path)
    task = test_client.post(
        "/agent/tasks",
        json={"objective": "Run good night", "context": "personal"},
        headers=auth(),
    ).json()
    approval_id = task["approvals"][0]["id"]

    with patch("httpx.Client") as mock_client_class:
        denied = test_client.post(
            f"/agent/approvals/{approval_id}",
            json={"decision": "deny"},
            headers=auth(),
        )
        mock_client_class.assert_not_called()

    assert denied.status_code == 200
    assert denied.json()["status"] == "denied"


def test_approved_scene_cannot_be_replayed(tmp_path: Path) -> None:
    def ollama_response(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        if payload["tools"]:
            return _scene_tool_call_response()
        return httpx.Response(200, json={"message": {"content": "Approve it."}})

    test_client = client(httpx.MockTransport(ollama_response), tmp_path)
    task = test_client.post(
        "/agent/tasks",
        json={"objective": "Run good night", "context": "personal"},
        headers=auth(),
    ).json()
    approval_id = task["approvals"][0]["id"]
    endpoint = f"/agent/approvals/{approval_id}"

    with patch("httpx.Client") as mock_client_class:
        mock_client = MagicMock()
        mock_client_class.return_value.__enter__.return_value = mock_client
        mock_client.post.return_value = MagicMock(status_code=200, json=lambda: {"context": "xyz"})

        first = test_client.post(endpoint, json={"decision": "approve"}, headers=auth())
        assert first.status_code == 200
        # Home Assistant is unconfigured in this fixture, so the tool itself
        # reports a graceful error rather than raising -- what matters here is
        # that a second approval attempt on the same id is rejected outright.
        second = test_client.post(endpoint, json={"decision": "approve"}, headers=auth())

    assert second.status_code == 409
