from __future__ import annotations

from pathlib import Path
from unittest.mock import MagicMock, patch

from fastapi.testclient import TestClient
from pydantic import SecretStr

from app.config import Settings
from app.main import create_app
from app.research import extract_sources_from_tool_results

TOKEN = "test-device-token"


def home_client(tmp_path: Path, **settings_overrides: object) -> TestClient:
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
        **settings_overrides,
    )
    return TestClient(create_app(settings))


def auth() -> dict[str, str]:
    return {"Authorization": f"Bearer {TOKEN}"}


def test_home_devices_requires_authentication(tmp_path: Path) -> None:
    client = home_client(tmp_path)

    assert client.get("/home/devices").status_code == 401


def test_home_devices_unconfigured(tmp_path: Path) -> None:
    client = home_client(tmp_path)

    response = client.get("/home/devices", headers=auth())

    assert response.status_code == 200
    body = response.json()
    assert body["configured"] is False
    assert body["devices"] == []
    assert "Home Assistant" in body["message"]


def test_home_devices_returns_mocked_states(tmp_path: Path) -> None:
    client = home_client(
        tmp_path,
        homeassistant_url="http://hass.local",
        homeassistant_token=SecretStr("test-token"),
    )
    mock_states = [
        {
            "entity_id": "light.living_room",
            "state": "on",
            "attributes": {"friendly_name": "Living Room Light"},
        },
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

        response = client.get("/home/devices", headers=auth())

    assert response.status_code == 200
    body = response.json()
    assert body["configured"] is True
    assert len(body["devices"]) == 2
    assert body["devices"][0]["entity_id"] == "light.living_room"
    assert body["devices"][0]["name"] == "Living Room Light"
    assert body["devices"][1]["domain"] == "lock"


def test_home_devices_domain_filter(tmp_path: Path) -> None:
    client = home_client(
        tmp_path,
        homeassistant_url="http://hass.local",
        homeassistant_token=SecretStr("test-token"),
    )
    mock_states = [
        {
            "entity_id": "light.living_room",
            "state": "on",
            "attributes": {"friendly_name": "Living Room Light"},
        },
        {
            "entity_id": "switch.coffee_maker",
            "state": "off",
            "attributes": {},
        },
    ]

    with patch("httpx.Client") as mock_client_class:
        mock_client = MagicMock()
        mock_client_class.return_value.__enter__.return_value = mock_client
        mock_client.get.return_value = MagicMock(status_code=200, json=lambda: mock_states)

        response = client.get("/home/devices?domain=light", headers=auth())

    assert response.status_code == 200
    body = response.json()
    assert len(body["devices"]) == 1
    assert body["devices"][0]["domain"] == "light"


def test_extract_sources_from_tool_results() -> None:
    sources = extract_sources_from_tool_results(
        [
            {
                "tool": "web_search",
                "result": {
                    "results": [
                        {"title": "Example", "url": "https://example.com/a"},
                        {"title": "Duplicate", "url": "https://example.com/a"},
                    ]
                },
            },
            {
                "tool": "read_url",
                "result": {"title": "Article", "url": "https://example.com/b"},
            },
            {
                "tool": "read_news_feeds",
                "result": {
                    "items": [{"title": "Headline", "url": "https://example.com/c"}]
                },
            },
        ]
    )

    assert len(sources) == 3
    assert sources[0]["kind"] == "web_search"
    assert sources[1]["kind"] == "read_url"
    assert sources[2]["kind"] == "news_feed"
