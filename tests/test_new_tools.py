"""Tests for the new research and monitoring tools added in the tool expansion sprint."""

from __future__ import annotations

from pathlib import Path
from typing import Any
from unittest.mock import MagicMock, patch

import pytest

from app.agent_store import AgentStore
from app.agent_tools import ToolRegistry
from app.config import Settings


def _registry(settings_overrides: dict[str, Any] | None = None) -> ToolRegistry:
    """Build a ToolRegistry backed by an in-memory store, with optional Settings overrides."""
    store = AgentStore(Path(":memory:"))
    base: dict[str, Any] = {
        "device_token": "test-token",
        "weather_latitude": 41.85,
        "weather_longitude": -87.65,
        "news_feed_urls": "https://example.com/feed.xml",
        "web_search_max_results": 3,
    }
    if settings_overrides:
        base.update(settings_overrides)
    settings = Settings.model_validate(base)
    return ToolRegistry(
        workspace=Path("/tmp/nobs-test-workspace"),
        store=store,
        settings=settings,
    )


# ------------------------------------------------------------------ #
# web_search                                                           #
# ------------------------------------------------------------------ #


class TestWebSearch:
    def test_returns_results(self) -> None:
        fake_results = [
            {"title": "Result 1", "href": "https://example.com/1", "body": "Snippet one."},
            {"title": "Result 2", "href": "https://example.com/2", "body": "Snippet two."},
        ]
        with patch("app.agent_tools.DDGS") as mock_ddgs:
            mock_ddgs.return_value.text.return_value = fake_results
            result = _registry().execute("web_search", {"query": "open source AI tools"})

        assert result["count"] == 2
        assert result["results"][0]["title"] == "Result 1"
        assert result["results"][0]["url"] == "https://example.com/1"
        assert result["results"][1]["snippet"] == "Snippet two."

    def test_respects_max_results_setting(self) -> None:
        with patch("app.agent_tools.DDGS") as mock_ddgs:
            mock_ddgs.return_value.text.return_value = []
            _registry({"web_search_max_results": 7}).execute("web_search", {"query": "test"})
            _, kwargs = mock_ddgs.return_value.text.call_args
            assert kwargs["max_results"] == 7

    def test_max_results_capped_at_10(self) -> None:
        with patch("app.agent_tools.DDGS") as mock_ddgs:
            mock_ddgs.return_value.text.return_value = []
            _registry().execute("web_search", {"query": "test", "max_results": 99})
            _, kwargs = mock_ddgs.return_value.text.call_args
            assert kwargs["max_results"] == 10

    def test_empty_query_raises(self) -> None:
        with pytest.raises(ValueError, match="required"):
            _registry().execute("web_search", {"query": "   "})

    def test_ddgs_error_returns_error_dict(self) -> None:
        with patch("app.agent_tools.DDGS") as mock_ddgs:
            mock_ddgs.return_value.text.side_effect = RuntimeError("network down")
            result = _registry().execute("web_search", {"query": "test"})
        assert "error" in result


# ------------------------------------------------------------------ #
# get_weather                                                          #
# ------------------------------------------------------------------ #


class TestGetWeather:
    _MOCK_RESPONSE = {
        "timezone": "America/Chicago",
        "current": {
            "temperature_2m": 72.5,
            "apparent_temperature": 70.1,
            "relative_humidity_2m": 55,
            "wind_speed_10m": 8.3,
            "precipitation": 0.0,
            "weather_code": 1,
        },
        "daily": {
            "time": ["2026-07-05", "2026-07-06"],
            "temperature_2m_max": [80.0, 82.0],
            "temperature_2m_min": [65.0, 67.0],
            "precipitation_sum": [0.0, 0.1],
            "weather_code": [1, 3],
            "sunrise": ["2026-07-05T05:32", "2026-07-06T05:33"],
            "sunset": ["2026-07-05T20:28", "2026-07-06T20:27"],
        },
    }

    def test_returns_current_and_forecast(self) -> None:
        mock_response = MagicMock()
        mock_response.json.return_value = self._MOCK_RESPONSE
        mock_response.raise_for_status = MagicMock()

        with patch("app.agent_tools.httpx.Client") as mock_client:
            mock_client.return_value.__enter__.return_value.get.return_value = mock_response
            result = _registry().execute("get_weather", {})

        assert result["timezone"] == "America/Chicago"
        assert result["current"]["temperature_f"] == 72.5
        assert len(result["forecast_7day"]) == 2
        assert result["forecast_7day"][0]["date"] == "2026-07-05"
        assert result["forecast_7day"][1]["high_f"] == 82.0

    def test_no_config_returns_error(self) -> None:
        result = _registry({"weather_latitude": None, "weather_longitude": None}).execute(
            "get_weather", {}
        )
        assert "error" in result
        assert "NOBS_WEATHER_LATITUDE" in result["error"]

    def test_http_error_returns_error_dict(self) -> None:
        with patch("app.agent_tools.httpx.Client") as mock_client:
            mock_client.return_value.__enter__.return_value.get.side_effect = Exception("timeout")
            result = _registry().execute("get_weather", {})
        assert "error" in result


# ------------------------------------------------------------------ #
# read_news_feeds                                                      #
# ------------------------------------------------------------------ #


class TestReadNewsFeeds:
    _MOCK_FEED = MagicMock()

    def _make_feed(self, entries: list[dict[str, str]]) -> MagicMock:
        feed_mock = MagicMock()
        feed_mock.feed.get.return_value = "Test Feed"
        feed_mock.entries = [
            MagicMock(**{"get.side_effect": lambda k, d="": e.get(k, d)}) for e in entries
        ]
        return feed_mock

    def test_returns_headlines(self) -> None:
        entries = [
            {
                "title": "Headline 1",
                "link": "https://ex.com/1",
                "summary": "Sum 1",
                "published": "2026-07-05",
            },
            {
                "title": "Headline 2",
                "link": "https://ex.com/2",
                "summary": "Sum 2",
                "published": "2026-07-05",
            },
        ]
        with patch("app.agent_tools.feedparser.parse") as mock_parse:
            mock_feed = MagicMock()
            mock_feed.feed.get.return_value = "Test Feed"
            mock_entries = []
            for e in entries:
                m = MagicMock()
                m.get = lambda k, d="", _e=e: _e.get(k, d)
                mock_entries.append(m)
            mock_feed.entries = mock_entries
            mock_parse.return_value = mock_feed
            result = _registry().execute("read_news_feeds", {})

        assert result["count"] == 2
        assert result["items"][0]["title"] == "Headline 1"

    def test_no_config_returns_error(self) -> None:
        result = _registry({"news_feed_urls": ""}).execute("read_news_feeds", {})
        assert "error" in result
        assert "NOBS_NEWS_FEED_URLS" in result["error"]

    def test_feed_error_captured_in_errors_list(self) -> None:
        with patch("app.agent_tools.feedparser.parse") as mock_parse:
            mock_parse.side_effect = Exception("connection refused")
            result = _registry().execute("read_news_feeds", {})
        assert "errors" in result


# ------------------------------------------------------------------ #
# read_url                                                             #
# ------------------------------------------------------------------ #


class TestReadUrl:
    def test_returns_extracted_content(self) -> None:
        with (
            patch("app.agent_tools.trafilatura.fetch_url") as mock_fetch,
            patch("app.agent_tools.trafilatura.extract") as mock_extract,
        ):
            mock_fetch.return_value = "<html>...</html>"
            mock_extract.return_value = "This is the article text."
            result = _registry().execute("read_url", {"url": "https://example.com/article"})

        assert result["content"] == "This is the article text."
        assert result["truncated"] is False

    def test_non_http_url_raises(self) -> None:
        with pytest.raises(ValueError, match="HTTP"):
            _registry().execute("read_url", {"url": "file:///etc/passwd"})

    def test_private_network_url_raises(self) -> None:
        with pytest.raises(ValueError, match="not allowed"):
            _registry().execute("read_url", {"url": "http://127.0.0.1/internal"})

    def test_fetch_returns_none_gives_error(self) -> None:
        with patch("app.agent_tools.trafilatura.fetch_url", return_value=None):
            result = _registry().execute("read_url", {"url": "https://example.com"})
        assert "error" in result

    def test_no_extractable_content_gives_error(self) -> None:
        with (
            patch("app.agent_tools.trafilatura.fetch_url", return_value="<html/>"),
            patch("app.agent_tools.trafilatura.extract", return_value=None),
        ):
            result = _registry().execute("read_url", {"url": "https://example.com"})
        assert "error" in result

    def test_long_content_is_truncated(self) -> None:
        big_text = "word " * 5000  # 25k chars
        with (
            patch("app.agent_tools.trafilatura.fetch_url", return_value="<html/>"),
            patch("app.agent_tools.trafilatura.extract", return_value=big_text),
        ):
            result = _registry().execute("read_url", {"url": "https://example.com"})
        assert result["truncated"] is True
        assert len(result["content"]) <= 20_000


# ------------------------------------------------------------------ #
# lookup_wikipedia                                                     #
# ------------------------------------------------------------------ #


class TestLookupWikipedia:
    def _mock_page(
        self, exists: bool = True, summary: str = "Test summary. Second sentence."
    ) -> MagicMock:
        page = MagicMock()
        page.exists.return_value = exists
        page.title = "Test Article"
        page.fullurl = "https://en.wikipedia.org/wiki/Test_Article"
        page.summary = summary
        return page

    def test_returns_summary(self) -> None:
        with patch("app.agent_tools.wikipediaapi.Wikipedia") as mock_wiki:
            mock_wiki.return_value.page.return_value = self._mock_page()
            result = _registry().execute("lookup_wikipedia", {"query": "Python programming"})

        assert result["found"] is True
        assert result["title"] == "Test Article"
        assert "summary" in result

    def test_not_found_returns_found_false(self) -> None:
        with patch("app.agent_tools.wikipediaapi.Wikipedia") as mock_wiki:
            mock_wiki.return_value.page.return_value = self._mock_page(exists=False)
            result = _registry().execute("lookup_wikipedia", {"query": "xyzzy not a real thing"})

        assert result["found"] is False

    def test_exception_returns_error(self) -> None:
        with patch("app.agent_tools.wikipediaapi.Wikipedia") as mock_wiki:
            mock_wiki.return_value.page.side_effect = RuntimeError("network error")
            result = _registry().execute("lookup_wikipedia", {"query": "anything"})
        assert "error" in result


# ------------------------------------------------------------------ #
# get_tank_status (upgraded)                                           #
# ------------------------------------------------------------------ #


class TestGetTankStatusUpgraded:
    def test_returns_cpu_memory_disk(self) -> None:
        result = _registry().execute("get_tank_status", {})
        assert "cpu_percent" in result
        assert "memory_used_gb" in result
        assert "memory_total_gb" in result
        assert "memory_percent" in result
        assert "disk_free_gb" in result
        assert "disk_used_gb" in result
        assert "disk_total_gb" in result
        assert "hostname" in result
        assert "platform" in result

    def test_values_are_numeric(self) -> None:
        result = _registry().execute("get_tank_status", {})
        assert isinstance(result["cpu_percent"], float | int)
        assert isinstance(result["memory_total_gb"], float)
        assert result["memory_percent"] >= 0
        assert result["disk_total_gb"] > 0
