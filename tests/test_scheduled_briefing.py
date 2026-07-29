"""The scheduled briefing must fire at the user's local time and be as good as
a requested one.

Two defects are pinned here. Schedules are local wall-clock times but were
compared against UTC, so a 07:00 briefing arrived at 01:00 or 02:00 local. And
the scheduled path parsed model output with bare `.get()` calls instead of
validating it, and skipped the heuristic conflict detection that `POST /briefing`
applies -- so automatic briefings silently lost the overload and overlap warnings
that are the point of the feature.
"""

import asyncio
from datetime import UTC, datetime
import json

import httpx

from app.agent_store import AgentStore
from app.config import Settings
from app.scheduler import (
    due_schedules,
    local_hhmm,
    local_today,
    trigger_briefing_generation,
)

CHICAGO = "America/Chicago"


def _settings(**overrides) -> Settings:
    return Settings(agent_database_path=":memory:", **overrides)


def _schedule(time_of_day: str, schedule_id: str = "s1") -> dict:
    return {"id": schedule_id, "time_of_day": time_of_day, "status": "active"}


def _model(sections: dict) -> httpx.MockTransport:
    return httpx.MockTransport(
        lambda _: httpx.Response(200, json={"message": {"content": json.dumps(sections)}})
    )


def _valid_sections(**overrides) -> dict:
    base = {
        "topline": "A steady day.",
        "priorities": ["Business · Design sync (10:00)"],
        "conflicts_or_risks": [],
        "recommended_plan": ["Prep before 10:00."],
        "one_useful_question": None,
        "suggested_next_actions": ["Review notes."],
    }
    base.update(overrides)
    return base


# ------------------------------------------------------------------ #
# Local time (#5)                                                      #
# ------------------------------------------------------------------ #


def test_seven_am_chicago_schedule_does_not_fire_at_seven_utc() -> None:
    settings = _settings(timezone=CHICAGO)
    # 07:00 UTC is 02:00 in Chicago (July, so CDT = UTC-5). The old UTC
    # comparison fired here, waking the user in the middle of the night.
    seven_utc = datetime(2026, 7, 4, 7, 0, tzinfo=UTC)

    assert local_hhmm(settings, seven_utc) == "02:00"
    assert due_schedules([_schedule("07:00")], settings, seven_utc) == []


def test_seven_am_chicago_schedule_fires_at_noon_utc() -> None:
    settings = _settings(timezone=CHICAGO)
    noon_utc = datetime(2026, 7, 4, 12, 0, tzinfo=UTC)

    assert local_hhmm(settings, noon_utc) == "07:00"
    assert [s["id"] for s in due_schedules([_schedule("07:00")], settings, noon_utc)] == ["s1"]


def test_utc_timezone_is_unchanged() -> None:
    """The default configuration must keep behaving as before."""
    settings = _settings(timezone="UTC")
    seven_utc = datetime(2026, 7, 4, 7, 0, tzinfo=UTC)

    assert due_schedules([_schedule("07:00")], settings, seven_utc)


def test_unrecognized_timezone_falls_back_to_utc() -> None:
    settings = _settings(timezone="Not/AZone")
    seven_utc = datetime(2026, 7, 4, 7, 0, tzinfo=UTC)

    assert local_hhmm(settings, seven_utc) == "07:00"


def test_local_date_is_used_late_in_the_evening() -> None:
    """At 23:30 Chicago the UTC date has already rolled over."""
    settings = _settings(timezone=CHICAGO)
    late = datetime(2026, 7, 5, 4, 30, tzinfo=UTC)  # 23:30 on the 4th, Chicago

    assert late.date().isoformat() == "2026-07-05"
    assert local_today(settings, late).isoformat() == "2026-07-04"


def test_multiple_schedules_on_the_same_minute_are_reported_together() -> None:
    settings = _settings(timezone="UTC")
    now = datetime(2026, 7, 4, 7, 0, tzinfo=UTC)

    due = due_schedules([_schedule("07:00", "a"), _schedule("07:00", "b")], settings, now)

    # The loop generates one briefing for the whole set rather than one per
    # schedule, so both appear in a single decision.
    assert [s["id"] for s in due] == ["a", "b"]




# ------------------------------------------------------------------ #
# Shared pipeline (#6)                                                 #
# ------------------------------------------------------------------ #


def _run_scheduled(store: AgentStore, transport: httpx.MockTransport, **overrides) -> None:
    asyncio.run(
        trigger_briefing_generation(_settings(**overrides), store, transport)
    )


def test_scheduled_briefing_applies_conflict_heuristics() -> None:
    """The model reports no risks; the heuristics must still catch the overlap."""
    store = AgentStore(":memory:")
    store.sync_calendar(
        [
            {
                "title": "Design sync",
                "start": "10:00",
                "end": "11:00",
                "location": "Room 2",
                "context": "business",
            },
            {
                "title": "Dentist",
                "start": "10:30",
                "end": "11:30",
                "location": None,
                "context": "personal",
            },
        ]
    )

    _run_scheduled(store, _model(_valid_sections(conflicts_or_risks=[])), timezone="UTC")

    briefing = store.latest_briefing()
    assert briefing is not None
    risks = " ".join(briefing["conflicts_or_risks"]).lower()
    assert "overlap" in risks
    # And the clarifying question the heuristics add for overlaps.
    assert "must-attend" in (briefing["one_useful_question"] or "")


def test_scheduled_briefing_sends_end_times_to_the_model() -> None:
    """Without end times the heuristics cannot detect overlaps at all."""
    store = AgentStore(":memory:")
    store.sync_calendar(
        [
            {
                "title": "Design sync",
                "start": "10:00",
                "end": "11:00",
                "location": "Room 2",
                "context": "business",
            }
        ]
    )
    store.sync_reminders([{"title": "Call plumber", "due": "14:00", "context": "personal"}])
    seen: dict = {}

    def capture(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        seen.update(json.loads(payload["messages"][1]["content"]))
        return httpx.Response(200, json={"message": {"content": json.dumps(_valid_sections())}})

    _run_scheduled(store, httpx.MockTransport(capture), timezone="UTC")

    assert seen["calendar"][0]["end"] == "11:00"
    assert seen["calendar"][0]["location"] == "Room 2"
    assert seen["reminders"][0]["due"] == "14:00"


def test_invalid_model_output_is_not_persisted() -> None:
    """Unvalidated output previously reached storage and broke /briefing/latest."""
    store = AgentStore(":memory:")
    store.sync_calendar(
        [{"title": "Design sync", "start": "10:00", "end": "11:00", "context": "business"}]
    )
    garbage = httpx.MockTransport(
        lambda _: httpx.Response(200, json={"message": {"content": "not json at all"}})
    )

    _run_scheduled(store, garbage)

    assert store.latest_briefing() is None


def test_model_missing_required_field_is_not_persisted() -> None:
    store = AgentStore(":memory:")

    _run_scheduled(store, _model({"priorities": ["a"]}))  # no topline

    assert store.latest_briefing() is None


def test_unreachable_model_is_handled_without_raising() -> None:
    store = AgentStore(":memory:")

    def refuse(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no ollama", request=request)

    _run_scheduled(store, httpx.MockTransport(refuse))

    assert store.latest_briefing() is None


def test_successful_briefing_is_recorded_as_an_audited_run() -> None:
    store = AgentStore(":memory:")

    _run_scheduled(store, _model(_valid_sections()))

    assert store.latest_briefing() is not None
    assert store.dashboard_metrics()["last_activity_at"] is not None
