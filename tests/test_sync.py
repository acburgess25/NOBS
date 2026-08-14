import sqlite3

from app.agent_store import AgentStore
from tests.test_chat import auth, client

CALENDAR_PAYLOAD = {
    "events": [
        {
            "title": "Design sync",
            "start": "2026-07-05T10:00:00Z",
            "end": "2026-07-05T11:00:00Z",
            "location": "Room 2",
            "context": "business",
        },
        {"title": "School pickup", "start": "2026-07-05T15:30:00Z", "context": "shared"},
    ]
}

REMINDER_PAYLOAD = {
    "reminders": [
        {"title": "Pay electric bill", "due": "2026-07-05T17:00:00Z", "context": "personal"},
        {"title": "Prepare slides", "context": "business"},
    ]
}


def test_sync_routes_require_authentication() -> None:
    test_client = client()

    assert test_client.post("/sync/calendar", json=CALENDAR_PAYLOAD).status_code == 401
    assert test_client.post("/sync/reminders", json=REMINDER_PAYLOAD).status_code == 401


def test_sync_calendar_persists_latest_payload() -> None:
    test_client = client()

    response = test_client.post("/sync/calendar", json=CALENDAR_PAYLOAD, headers=auth())

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    events = test_client.app.state.agent_store.list_calendar_events()
    assert len(events) == 2
    assert {event["title"] for event in events} == {"Design sync", "School pickup"}
    assert {event["context"] for event in events} == {"business", "shared"}


def test_sync_reminders_persists_latest_payload() -> None:
    test_client = client()

    response = test_client.post("/sync/reminders", json=REMINDER_PAYLOAD, headers=auth())

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    reminders = test_client.app.state.agent_store.list_reminders()
    assert len(reminders) == 2
    assert {item["title"] for item in reminders} == {"Pay electric bill", "Prepare slides"}
    assert {item["context"] for item in reminders} == {"personal", "business"}


def test_sync_calendar_keeps_end_and_location() -> None:
    """These were accepted by the API and then dropped on write.

    The briefing heuristics need end times to detect overlapping and
    back-to-back events, so discarding them silently disabled conflict
    detection for every briefing built from synced data.
    """
    test_client = client()

    test_client.post("/sync/calendar", json=CALENDAR_PAYLOAD, headers=auth())

    events = {e["title"]: e for e in test_client.app.state.agent_store.list_calendar_events()}
    assert events["Design sync"]["end"] == "2026-07-05T11:00:00Z"
    assert events["Design sync"]["location"] == "Room 2"
    # Absent optional fields stay absent rather than becoming empty strings.
    assert events["School pickup"]["end"] is None
    assert events["School pickup"]["location"] is None


def test_sync_reminders_keeps_due() -> None:
    test_client = client()

    test_client.post("/sync/reminders", json=REMINDER_PAYLOAD, headers=auth())

    reminders = {r["title"]: r for r in test_client.app.state.agent_store.list_reminders()}
    assert reminders["Pay electric bill"]["due"] == "2026-07-05T17:00:00Z"
    assert reminders["Prepare slides"]["due"] is None


def test_columns_are_added_to_an_existing_database(tmp_path) -> None:
    """An already-deployed Tank must gain the new columns on open.

    `CREATE TABLE IF NOT EXISTS` does nothing to a table that already exists, so
    without a migration an existing database would keep the old shape and fail
    at query time.
    """
    database = tmp_path / "old-tank.db"
    legacy = sqlite3.connect(database)
    legacy.executescript(
        """
        CREATE TABLE calendar_events (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            start TEXT NOT NULL,
            context TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        CREATE TABLE reminders (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            context TEXT NOT NULL,
            created_at TEXT NOT NULL
        );
        INSERT INTO calendar_events VALUES ('1', 'Existing event', '09:00', 'personal', 'then');
        INSERT INTO reminders VALUES ('2', 'Existing reminder', 'personal', 'then');
        """
    )
    legacy.commit()
    legacy.close()

    store = AgentStore(database)
    events = store.list_calendar_events()
    reminders = store.list_reminders()

    # Existing rows survive and read back with the new fields empty.
    assert events[0]["title"] == "Existing event"
    assert events[0]["end"] is None
    assert events[0]["location"] is None
    assert reminders[0]["title"] == "Existing reminder"
    assert reminders[0]["due"] is None

    # And the migrated table accepts writes that use the new columns.
    store.sync_calendar(
        [{"title": "New", "start": "10:00", "end": "11:00", "context": "business"}]
    )
    assert store.list_calendar_events()[0]["end"] == "11:00"


def test_migration_is_idempotent(tmp_path) -> None:
    database = tmp_path / "tank.db"
    AgentStore(database).list_calendar_events()

    reopened = AgentStore(database)
    reopened.sync_reminders([{"title": "Still fine", "due": "08:00", "context": "personal"}])

    assert reopened.list_reminders()[0]["due"] == "08:00"
