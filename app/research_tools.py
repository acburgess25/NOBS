"""Read-only research tools: web search, weather, news, page text, Wikipedia.

These are the tools the agent may run without an approval, so each one is
written to fail closed and to say *why* it failed. They reach the public
internet and nothing else -- no Tank state, no workspace, no Home Assistant --
which is what lets them live outside `ToolRegistry` as plain functions of
`settings` and the call arguments.

`ToolRegistry` wraps each one as a `ToolDefinition`; keeping the bodies here
means the registry file stays a readable catalogue of what the agent can do
rather than a 1,100-line mixture of catalogue and implementation.
"""

from __future__ import annotations

from typing import Any

import feedparser
import httpx
import trafilatura
import wikipediaapi
from ddgs import DDGS

from app.networking import is_public_http_url


def require_argument_keys(arguments: dict[str, Any], allowed: set[str]) -> None:
    if not isinstance(arguments, dict) or not set(arguments).issubset(allowed):
        raise ValueError("Tool arguments contain unsupported fields")


def web_search(settings: Any, arguments: dict[str, Any]) -> dict[str, Any]:
    require_argument_keys(arguments, {"query", "max_results"})
    query = str(arguments.get("query", "")).strip()
    if not query:
        raise ValueError("Search query is required")
    max_results = int(
        arguments.get("max_results") or (settings.web_search_max_results if settings else 5)
    )
    max_results = max(1, min(max_results, 10))
    try:
        raw = list(DDGS().text(query, max_results=max_results))
    except Exception as exc:
        return {"error": f"Web search failed: {exc}"}
    results = [
        {"title": r.get("title", ""), "url": r.get("href", ""), "snippet": r.get("body", "")}
        for r in raw
    ]
    if not results:
        # An empty list is usually the provider throttling or not matching, not an
        # answer. Say so, or the model reads silence as "nothing exists" and retries.
        return {
            "query": query,
            "results": [],
            "count": 0,
            "note": "The search provider returned no results. Try different wording.",
        }
    return {"query": query, "results": results, "count": len(results)}


def get_weather(settings: Any, _: dict[str, Any]) -> dict[str, Any]:
    if not settings or settings.weather_latitude is None:
        return {
            "error": (
                "Weather is not configured. "
                "Set NOBS_WEATHER_LATITUDE and NOBS_WEATHER_LONGITUDE in your environment."
            )
        }
    lat = settings.weather_latitude
    lon = settings.weather_longitude
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={lat}&longitude={lon}"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
        "precipitation,wind_speed_10m,weather_code"
        "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,"
        "weather_code,sunrise,sunset"
        "&temperature_unit=fahrenheit&wind_speed_unit=mph"
        "&precipitation_unit=inch&timezone=auto&forecast_days=7"
    )
    try:
        with httpx.Client(timeout=10.0) as client:
            response = client.get(url)
            response.raise_for_status()
        data = response.json()
    except Exception as exc:
        return {"error": f"Weather fetch failed: {exc}"}
    current = data.get("current", {})
    daily = data.get("daily", {})
    forecast = []
    dates = daily.get("time", [])
    for i, date in enumerate(dates):
        forecast.append(
            {
                "date": date,
                "high_f": daily.get("temperature_2m_max", [None])[i],
                "low_f": daily.get("temperature_2m_min", [None])[i],
                "precipitation_in": daily.get("precipitation_sum", [None])[i],
                "weather_code": daily.get("weather_code", [None])[i],
                "sunrise": daily.get("sunrise", [None])[i],
                "sunset": daily.get("sunset", [None])[i],
            }
        )
    return {
        "latitude": lat,
        "longitude": lon,
        "timezone": data.get("timezone"),
        "current": {
            "temperature_f": current.get("temperature_2m"),
            "feels_like_f": current.get("apparent_temperature"),
            "humidity_pct": current.get("relative_humidity_2m"),
            "wind_mph": current.get("wind_speed_10m"),
            "precipitation_in": current.get("precipitation"),
            "weather_code": current.get("weather_code"),
        },
        "forecast_7day": forecast,
    }


def read_news_feeds(settings: Any, arguments: dict[str, Any]) -> dict[str, Any]:
    require_argument_keys(arguments, {"max_per_feed"})
    max_per_feed = int(arguments.get("max_per_feed") or 5)
    max_per_feed = max(1, min(max_per_feed, 20))
    raw_urls = (settings.news_feed_urls if settings else "").strip()
    if not raw_urls:
        return {
            "error": (
                "No news feeds configured. "
                "Set NOBS_NEWS_FEED_URLS to a comma-separated list of RSS/Atom URLs."
            )
        }
    feed_urls = [u.strip() for u in raw_urls.split(",") if u.strip()]
    all_items: list[dict[str, Any]] = []
    errors: list[str] = []
    for url in feed_urls[:10]:
        try:
            parsed = feedparser.parse(url)
            feed_title = parsed.feed.get("title", url)
            for entry in parsed.entries[:max_per_feed]:
                all_items.append(
                    {
                        "feed": feed_title,
                        "title": entry.get("title", ""),
                        "url": entry.get("link", ""),
                        "summary": entry.get("summary", "")[:500],
                        "published": entry.get("published", ""),
                    }
                )
        except Exception as exc:
            errors.append(f"{url}: {exc}")
    result: dict[str, Any] = {"items": all_items, "count": len(all_items)}
    if errors:
        result["errors"] = errors
    return result


def read_url(arguments: dict[str, Any]) -> dict[str, Any]:
    require_argument_keys(arguments, {"url"})
    url = str(arguments.get("url", "")).strip()
    if not url:
        raise ValueError("URL is required")
    # This tool runs automatically without approval, and the URL can come
    # from model output shaped by a fetched page or search result. Confine it
    # to public hosts so it can never be turned into a reader for the Tank's
    # own API, Home Assistant, or anything else on the local network.
    if not is_public_http_url(url):
        raise ValueError(
            "Only public HTTP and HTTPS URLs are allowed. Local and private "
            "network addresses cannot be read."
        )
    try:
        # Fetched here rather than with trafilatura.fetch_url, which follows
        # redirects: an allowed public page could otherwise 302 to loopback
        # or a LAN address and the host check would never see it.
        with httpx.Client(timeout=15.0, follow_redirects=False) as client:
            response = client.get(url, headers={"User-Agent": "NOBS-Tank/0.1"})
        if response.is_redirect:
            return {
                "error": (
                    "That URL redirects elsewhere. Redirects are not followed, so "
                    "give the final URL directly."
                )
            }
        response.raise_for_status()
        text = trafilatura.extract(response.text, include_comments=False, include_tables=True)
        if not text:
            return {"error": "Could not extract readable content from the URL"}
        truncated = len(text) > 20_000
        return {
            "url": url,
            "content": text[:20_000],
            "truncated": truncated,
            "char_count": len(text),
        }
    except (httpx.HTTPError, ValueError, OSError, TypeError) as exc:
        return {"error": f"Failed to read URL: {exc}"}


def lookup_wikipedia(arguments: dict[str, Any]) -> dict[str, Any]:
    require_argument_keys(arguments, {"query", "sentences"})
    query = str(arguments.get("query", "")).strip()
    if not query:
        raise ValueError("Search query is required")
    sentences = int(arguments.get("sentences") or 5)
    sentences = max(1, min(sentences, 20))
    try:
        wiki = wikipediaapi.Wikipedia(
            user_agent="NOBS-Tank/0.1 (private home assistant)",
            language="en",
        )
        page = wiki.page(query)
        if not page.exists():
            search_terms = query.replace(" ", "_")
            page = wiki.page(search_terms)
        if not page.exists():
            return {"query": query, "found": False, "error": "No Wikipedia article found"}
        full_summary = page.summary
        # Return approximately the requested number of sentences
        sent_list = full_summary.split(". ")
        summary = ". ".join(sent_list[:sentences])
        if not summary.endswith("."):
            summary += "."
        return {
            "query": query,
            "found": True,
            "title": page.title,
            "url": page.fullurl,
            "summary": summary,
            "full_summary_available": len(sent_list) > sentences,
        }
    except Exception as exc:
        return {"error": f"Wikipedia lookup failed: {exc}"}
