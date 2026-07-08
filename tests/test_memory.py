from __future__ import annotations

from app.memory import (
    extract_correction,
    extract_forget_request,
    extract_remember_request,
    infer_category,
    infer_memory_from_message,
    memory_categories_used,
)


def test_extract_remember_request() -> None:
    assert extract_remember_request("Remember that I like tea") == "I like tea"
    assert extract_remember_request("remember: standups at 9") == "standups at 9"
    assert extract_remember_request("plan my day") is None


def test_extract_forget_request() -> None:
    assert extract_forget_request("Forget that quiet mornings") == "quiet mornings"
    assert extract_forget_request("delete memory about tea") == "tea"


def test_extract_correction() -> None:
    assert extract_correction("Actually, I prefer coffee") == "I prefer coffee"
    assert extract_correction("Correct that to standups at 10") == "standups at 10"


def test_infer_category() -> None:
    assert infer_category("My wife prefers dinner at 6") == "relationship"
    assert infer_category("Don't schedule me before 9am") == "schedule"
    assert infer_category("I prefer tea") == "preference"


def test_infer_memory_from_message_skips_explicit_commands() -> None:
    assert infer_memory_from_message("Remember that I like tea") is None
    assert infer_memory_from_message("Forget that tea") is None


def test_infer_memory_from_preference_pattern() -> None:
    inferred = infer_memory_from_message("I prefer to batch email after lunch")
    assert inferred is not None
    assert inferred[1] == "preference"


def test_memory_categories_used_dedupes() -> None:
    memories = [
        {"category": "preference"},
        {"category": "schedule"},
        {"category": "preference"},
    ]
    assert memory_categories_used(memories) == ["preference", "schedule"]
