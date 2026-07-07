from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch
import pytest
from pydantic import SecretStr

from app.agent_tools import ToolRegistry
from app.home_assistant import HomeAssistantClient


def test_read_workspace_file(tmp_path: Path) -> None:
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    personal_dir = workspace / "personal"
    personal_dir.mkdir()
    (personal_dir / "note.md").write_text("Hello personal workspace!", encoding="utf-8")

    tools = ToolRegistry(workspace)

    # Valid read
    result = tools.execute("read_workspace_file", {"context": "personal", "path": "note.md"})
    assert result == {
        "context": "personal",
        "path": "note.md",
        "content": "Hello personal workspace!",
        "truncated": False,
    }

    # Escaping traversal
    with pytest.raises(ValueError, match="escapes context workspace"):
        tools.execute("read_workspace_file", {"context": "personal", "path": "../outside.md"})

    # Nonexistent file
    with pytest.raises(FileNotFoundError):
        tools.execute("read_workspace_file", {"context": "personal", "path": "missing.md"})


def test_home_assistant_unconfigured(tmp_path: Path) -> None:
    # URL and token empty
    client = HomeAssistantClient("", None)
    assert not client.is_configured

    tools = ToolRegistry(tmp_path, home_assistant=client)

    # list_home_devices returns error response
    res = tools.execute("list_home_devices", {})
    assert "not configured" in res["error"]

    # control_home_device returns error response
    res = tools.execute("control_home_device", {"entity_id": "light.bedroom", "service": "turn_on"})
    assert "not configured" in res["error"]


def test_list_home_devices_mock(tmp_path: Path) -> None:
    client = HomeAssistantClient("http://hass.local", SecretStr("test-token"))
    tools = ToolRegistry(tmp_path, home_assistant=client)

    mock_states = [
        {
            "entity_id": "light.living_room",
            "state": "on",
            "attributes": {"friendly_name": "Living Room Light"},
        },
        {"entity_id": "switch.coffee_maker", "state": "off", "attributes": {}},
        {
            "entity_id": "lock.front_door",
            "state": "locked",
            "attributes": {"friendly_name": "Front Door"},
        },
    ]

    with patch("httpx.Client") as mock_client_class:
        mock_client = MagicMock()
        mock_client_class.return_value.__enter__.return_value = mock_client
        mock_client.get.return_value = MagicMock(status_code=200, json=lambda: mock_states)

        # No filter
        res = tools.execute("list_home_devices", {})
        assert len(res["devices"]) == 3
        assert res["devices"][0]["name"] == "Living Room Light"
        assert res["devices"][1]["name"] == "switch.coffee_maker"

        # Filter by domain
        res_filter = tools.execute("list_home_devices", {"domain": "lock"})
        assert len(res_filter["devices"]) == 1
        assert res_filter["devices"][0]["entity_id"] == "lock.front_door"


def test_control_home_device_separates_security_risk(tmp_path: Path) -> None:
    client = HomeAssistantClient("http://hass.local", SecretStr("test-token"))
    tools = ToolRegistry(tmp_path, home_assistant=client)

    # Standard tool should reject secure devices (lock/alarm/cover)
    with pytest.raises(ValueError, match="not permitted to control secure devices"):
        tools.execute("control_home_device", {"entity_id": "lock.front_door", "service": "unlock"})

    # Secure tool should reject standard devices (light/switch/climate)
    with pytest.raises(ValueError, match="only permitted to control secure devices"):
        tools.execute(
            "control_secure_home_device", {"entity_id": "light.kitchen", "service": "turn_on"}
        )


def test_control_home_device_mock(tmp_path: Path) -> None:
    client = HomeAssistantClient("http://hass.local", SecretStr("test-token"))
    tools = ToolRegistry(tmp_path, home_assistant=client)

    with patch("httpx.Client") as mock_client_class:
        mock_client = MagicMock()
        mock_client_class.return_value.__enter__.return_value = mock_client
        mock_client.post.return_value = MagicMock(status_code=200, json=lambda: {"context": "xyz"})

        # Call standard device light.turn_on
        res = tools.execute(
            "control_home_device",
            {
                "entity_id": "light.living_room",
                "service": "turn_on",
                "service_data": {"brightness": 255},
            },
        )
        assert res["status"] == "success"
        mock_client.post.assert_called_with(
            "http://hass.local/api/services/light/turn_on",
            headers={
                "Authorization": "Bearer test-token",
                "Content-Type": "application/json",
            },
            json={"brightness": 255, "entity_id": "light.living_room"},
        )

        # Call secure device lock.unlock
        res_secure = tools.execute(
            "control_secure_home_device",
            {
                "entity_id": "lock.front_door",
                "service": "unlock",
            },
        )
        assert res_secure["status"] == "success"
        mock_client.post.assert_called_with(
            "http://hass.local/api/services/lock/unlock",
            headers={
                "Authorization": "Bearer test-token",
                "Content-Type": "application/json",
            },
            json={"entity_id": "lock.front_door"},
        )
