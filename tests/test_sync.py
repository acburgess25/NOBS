from tests.test_chat import auth, client


CALENDAR_PAYLOAD = {
    "events": [
        {"title": "Design sync", "start": "2026-07-05T10:00:00Z", "context": "business"},
        {"title": "School pickup", "start": "2026-07-05T15:30:00Z", "context": "shared"},
    ]
}

REMINDER_PAYLOAD = {
    "reminders": [
        {"title": "Pay electric bill", "context": "personal"},
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
