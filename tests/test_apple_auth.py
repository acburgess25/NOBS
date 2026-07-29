"""Sign in with Apple exchanges an Apple user ID for the Tank device token.

The user identifier travels inside the request, so it proves nothing by itself.
Claiming an unpaired Tank therefore also needs a pairing window opened on the
Tank; see tests/test_pairing.py for that gate. These tests cover the exchange
itself once pairing is permitted.
"""

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

UID = "001234.abcdef1234567890"


def make_client() -> TestClient:
    """A client that is already allowed to pair, so tests can focus on the exchange."""
    app = create_app(Settings(agent_database_path=":memory:"))
    app.state.pairing_window.open()
    return TestClient(app)


def test_first_apple_signin_registers_and_returns_token() -> None:
    client = make_client()
    response = client.post(
        "/auth/apple",
        json={"user_identifier": UID, "identity_token": None},
    )
    assert response.status_code == 200
    data = response.json()
    assert "device_token" in data
    assert isinstance(data["device_token"], str)
    assert len(data["device_token"]) > 0


def test_same_apple_user_can_sign_in_again() -> None:
    client = make_client()
    first = client.post("/auth/apple", json={"user_identifier": UID})
    second = client.post("/auth/apple", json={"user_identifier": UID})
    assert second.status_code == 200
    assert second.json()["device_token"] == first.json()["device_token"]


def test_different_apple_user_is_rejected() -> None:
    client = make_client()
    client.post("/auth/apple", json={"user_identifier": UID})
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
        json={"user_identifier": UID},
        # No Authorization header
    )
    assert response.status_code == 200
