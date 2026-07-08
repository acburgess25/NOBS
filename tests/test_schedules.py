from __future__ import annotations

from pathlib import Path

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

TOKEN = "test-device-token"


def schedules_client(tmp_path: Path) -> TestClient:
    settings = Settings(
        device_token=TOKEN,
        agent_database_path=tmp_path / "agent.db",
        agent_workspace_path=tmp_path / "workspace",
    )
    return TestClient(create_app(settings))


def auth() -> dict[str, str]:
    return {"Authorization": f"Bearer {TOKEN}"}


def test_schedules_routes_require_authentication(tmp_path: Path) -> None:
    client = schedules_client(tmp_path)

    assert client.get("/schedules").status_code == 401
    assert client.post("/schedules", json={"time_of_day": "08:00"}).status_code == 401
    assert client.patch("/schedules/missing", json={"status": "paused"}).status_code == 401


def test_create_and_list_schedules(tmp_path: Path) -> None:
    client = schedules_client(tmp_path)
    headers = auth()

    create = client.post("/schedules", json={"time_of_day": "07:30"}, headers=headers)
    assert create.status_code == 200
    created = create.json()
    assert created["time_of_day"] == "07:30"
    assert created["status"] == "active"
    assert created["id"]
    assert created["created_at"]

    listed = client.get("/schedules", headers=headers)
    assert listed.status_code == 200
    schedules = listed.json()
    assert len(schedules) == 1
    assert schedules[0]["id"] == created["id"]


def test_create_schedule_rejects_invalid_time(tmp_path: Path) -> None:
    client = schedules_client(tmp_path)

    response = client.post("/schedules", json={"time_of_day": "25:99"}, headers=auth())

    assert response.status_code == 422


def test_update_schedule_pause_and_revoke(tmp_path: Path) -> None:
    client = schedules_client(tmp_path)
    headers = auth()
    schedule_id = client.post("/schedules", json={"time_of_day": "09:00"}, headers=headers).json()["id"]

    paused = client.patch(f"/schedules/{schedule_id}", json={"status": "paused"}, headers=headers)
    assert paused.status_code == 200
    assert paused.json()["status"] == "paused"

    revoked = client.patch(f"/schedules/{schedule_id}", json={"status": "revoked"}, headers=headers)
    assert revoked.status_code == 200
    assert revoked.json()["status"] == "revoked"


def test_update_schedule_returns_409_for_missing_schedule(tmp_path: Path) -> None:
    client = schedules_client(tmp_path)

    response = client.patch(
        "/schedules/does-not-exist",
        json={"status": "paused"},
        headers=auth(),
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Schedule is missing"


def test_update_schedule_rejects_invalid_status(tmp_path: Path) -> None:
    client = schedules_client(tmp_path)
    headers = auth()
    schedule_id = client.post("/schedules", json={"time_of_day": "10:15"}, headers=headers).json()["id"]

    response = client.patch(f"/schedules/{schedule_id}", json={"status": "deleted"}, headers=headers)

    assert response.status_code == 422
