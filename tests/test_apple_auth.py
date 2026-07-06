from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app


TOKEN = "test-device-token-for-apple-auth"


def make_client() -> TestClient:
    settings = Settings.model_validate({"device_token": TOKEN, "agent_database_path": ":memory:"})
    return TestClient(create_app(settings))


def test_first_apple_signin_registers_and_returns_token() -> None:
    client = make_client()
    response = client.post(
        "/auth/apple",
        json={"user_identifier": "001234.abcdef1234567890", "identity_token": None},
    )
    assert response.status_code == 200
    assert response.json()["device_token"] == TOKEN


def test_same_apple_user_can_sign_in_again() -> None:
    client = make_client()
    uid = "001234.abcdef1234567890"
    client.post("/auth/apple", json={"user_identifier": uid})
    response = client.post("/auth/apple", json={"user_identifier": uid})
    assert response.status_code == 200
    assert response.json()["device_token"] == TOKEN


def test_different_apple_user_is_rejected() -> None:
    client = make_client()
    client.post("/auth/apple", json={"user_identifier": "001234.abcdef1234567890"})
    response = client.post(
        "/auth/apple",
        json={"user_identifier": "999999.differentuser0000000"},
    )
    assert response.status_code == 403


def test_auth_apple_does_not_require_device_token_header() -> None:
    """Bootstrap endpoint must be reachable without a token."""
    client = make_client()
    response = client.post(
        "/auth/apple",
        json={"user_identifier": "001234.abcdef1234567890"},
        # No Authorization header
    )
    assert response.status_code == 200
