from __future__ import annotations

from typing import Any

from app.agent_store import AgentStore
from app.config import Settings

ENTITLEMENT_KV_KEY = "nobscloud_entitled"


def research_entitled(store: AgentStore, settings: Settings) -> bool:
    """Return True when research briefs are allowed for this Tank."""
    if settings.environment == "development":
        return True
    return store.get_kv(ENTITLEMENT_KV_KEY) == "true"


def entitlement_denied_detail() -> str:
    return (
        "Research briefs require an active NOBScloud subscription. "
        "Subscribe in NOBS Privacy → Support NOBS, then sync entitlement to Tank."
    )


def build_research_objective(topic: str) -> str:
    return (
        f"Research this topic and produce a concise sourced brief: {topic}. "
        "Use web_search, read_news_feeds, and read_url to gather current information. "
        "Summarize key findings with clear takeaways. Cite sources by title and URL. "
        "Do not call state-changing tools or propose actions that require approval."
    )


def extract_sources_from_tool_results(tool_results: list[dict[str, Any]]) -> list[dict[str, str]]:
    sources: list[dict[str, str]] = []
    seen_urls: set[str] = set()

    def add_source(title: str, url: str, kind: str) -> None:
        normalized_url = url.strip()
        if not normalized_url or normalized_url in seen_urls:
            return
        seen_urls.add(normalized_url)
        sources.append(
            {
                "title": title.strip() or normalized_url,
                "url": normalized_url,
                "kind": kind,
            }
        )

    for item in tool_results:
        tool = item.get("tool", "")
        result = item.get("result", {})
        if not isinstance(result, dict) or "error" in result:
            continue

        if tool == "web_search":
            for entry in result.get("results", []):
                if isinstance(entry, dict):
                    add_source(str(entry.get("title", "")), str(entry.get("url", "")), "web_search")
        elif tool == "read_url":
            add_source(str(result.get("title", "")), str(result.get("url", "")), "read_url")
        elif tool == "read_news_feeds":
            for entry in result.get("items", []):
                if isinstance(entry, dict):
                    add_source(str(entry.get("title", "")), str(entry.get("url", "")), "news_feed")

    return sources
