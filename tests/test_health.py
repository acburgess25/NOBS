from fastapi.testclient import TestClient

from app.main import create_app


def test_health_returns_service_metadata() -> None:
    response = TestClient(create_app()).get("/health")

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "ok"
    assert payload["service"] == "nobs-cloud"
    assert payload["version"]
    assert payload["timestamp"].endswith("+00:00")

