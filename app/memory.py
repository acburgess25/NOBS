from __future__ import annotations

import re
from typing import Any

MEMORY_CATEGORIES = frozenset(
    {"preference", "schedule", "relationship", "habit", "priority", "other"}
)
MEMORY_SOURCES = frozenset({"chat", "briefing", "user_explicit"})

_REMEMBER_PATTERNS = (
    re.compile(r"^remember\s+that\s+(.+)$", re.IGNORECASE),
    re.compile(r"^remember:\s*(.+)$", re.IGNORECASE),
)
_FORGET_PATTERNS = (
    re.compile(r"^forget\s+(?:that\s+)?(.+)$", re.IGNORECASE),
    re.compile(r"^delete\s+(?:the\s+)?memory\s+(?:about\s+)?(.+)$", re.IGNORECASE),
)
_CORRECT_PATTERNS = (
    re.compile(r"^correct\s+(?:that\s+)?(?:to\s+)?(.+)$", re.IGNORECASE),
    re.compile(r"^actually[,:\s]+(.+)$", re.IGNORECASE),
    re.compile(r"^that(?:'s| is)\s+wrong[,:\s]+(.+)$", re.IGNORECASE),
)
_INFER_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"\bi\s+prefer\s+(.+)", re.IGNORECASE), "preference"),
    (re.compile(r"\bi\s+(?:usually|always|never)\s+(.+)", re.IGNORECASE), "habit"),
    (
        re.compile(
            r"\b(?:don'?t|do not)\s+schedule\s+(?:me\s+)?(?:before|after)\s+(.+)",
            re.IGNORECASE,
        ),
        "schedule",
    ),
    (
        re.compile(r"\bmy\s+(?:wife|husband|partner|spouse|kid|child|children)\b", re.IGNORECASE),
        "relationship",
    ),
    (re.compile(r"\bmost\s+important(?:\s+today)?\s+is\s+(.+)", re.IGNORECASE), "priority"),
)


def infer_category(content: str) -> str:
    lowered = content.lower()
    if any(word in lowered for word in ("wife", "husband", "partner", "spouse", "kid", "child", "family")):
        return "relationship"
    if any(word in lowered for word in ("prefer", "like", "rather", "instead")):
        return "preference"
    if any(word in lowered for word in ("always", "usually", "never", "habit", "routine")):
        return "habit"
    if any(word in lowered for word in ("priority", "important", "focus on", "must")):
        return "priority"
    if any(word in lowered for word in ("calendar", "meeting", "schedule", "morning", "afternoon")):
        return "schedule"
    return "other"


def extract_remember_request(text: str) -> str | None:
    trimmed = text.strip()
    for pattern in _REMEMBER_PATTERNS:
        match = pattern.match(trimmed)
        if match:
            content = match.group(1).strip().rstrip(".")
            return content or None
    return None


def extract_forget_request(text: str) -> str | None:
    trimmed = text.strip()
    for pattern in _FORGET_PATTERNS:
        match = pattern.match(trimmed)
        if match:
            content = match.group(1).strip().rstrip(".")
            return content or None
    return None


def extract_correction(text: str) -> str | None:
    trimmed = text.strip()
    for pattern in _CORRECT_PATTERNS:
        match = pattern.match(trimmed)
        if match:
            content = match.group(1).strip().rstrip(".")
            return content or None
    return None


def infer_memory_from_message(text: str) -> tuple[str, str] | None:
    """Return (content, category) when a chat message looks like a durable fact."""
    if extract_remember_request(text) or extract_forget_request(text) or extract_correction(text):
        return None
    trimmed = text.strip()
    if len(trimmed) < 12:
        return None
    for pattern, category in _INFER_PATTERNS:
        match = pattern.search(trimmed)
        if match:
            snippet = match.group(1).strip().rstrip(".") if match.lastindex else trimmed
            if len(snippet) >= 8:
                return snippet, category
    return None


def _tokenize(value: str) -> set[str]:
    return {token for token in re.findall(r"[a-z0-9']+", value.lower()) if len(token) > 2}


def memory_matches_query(memory: dict[str, Any], query: str) -> bool:
    query_tokens = _tokenize(query)
    if not query_tokens:
        return False
    content_tokens = _tokenize(memory["content"])
    if not content_tokens:
        return False
    overlap = query_tokens & content_tokens
    return len(overlap) >= min(2, len(query_tokens))


def find_matching_memories(memories: list[dict[str, Any]], query: str) -> list[dict[str, Any]]:
    return [memory for memory in memories if memory_matches_query(memory, query)]


def memory_categories_used(memories: list[dict[str, Any]]) -> list[str]:
    seen: set[str] = set()
    ordered: list[str] = []
    for memory in memories:
        category = memory["category"]
        if category in seen:
            continue
        seen.add(category)
        ordered.append(category)
    return ordered


def format_memory_used_receipt(categories: list[str]) -> list[str]:
    if not categories:
        return []
    return [f"memory ({category})" for category in categories]
