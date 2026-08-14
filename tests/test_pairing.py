"""Pairing must require someone at the Tank, not merely someone on the network."""

import httpx
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.pairing import PairingWindow, is_loopback_client

LAN_CLIENT = ("192.168.1.50", 51000)
LOCAL_CLIENT = ("127.0.0.1", 51000)
APPLE_USER = "001234.abcdef1234567890"


def _app(**overrides):
    settings = Settings(
        agent_database_path=":memory:",
        device_token="pairing-test-token",
        **overrides,
    )
    app = create_app(settings)
    app.state.ollama_transport = httpx.MockTransport(
        lambda _: httpx.Response(200, json={"models": [{"name": "qwen3:8b"}]})
    )
    return app


def lan_client(app) -> TestClient:
    return TestClient(app, client=LAN_CLIENT)


def local_client(app) -> TestClient:
    return TestClient(app, client=LOCAL_CLIENT)


# ------------------------------------------------------------------ #
# is_loopback_client                                                   #
# ------------------------------------------------------------------ #


@pytest.mark.parametrize("host", ["127.0.0.1", "127.5.5.5", "::1"])
def test_loopback_addresses_are_local(host: str) -> None:
    assert is_loopback_client(host) is True


@pytest.mark.parametrize(
    "host",
    [
        None,
        "",
        "192.168.1.50",
        "10.0.0.4",
        "8.8.8.8",
        # Starlette's placeholder, and anything else non-numeric, must not be
        # mistaken for a local peer.
        "testclient",
        "localhost",
    ],
)
def test_non_loopback_values_are_remote(host: str | None) -> None:
    assert is_loopback_client(host) is False


# ------------------------------------------------------------------ #
# Reading the token                                                    #
# ------------------------------------------------------------------ #


def test_lan_client_cannot_read_the_device_token() -> None:
    response = lan_client(_app()).get("/dashboard/pairing")

    assert response.status_code == 403
    assert "pairing-test-token" not in response.text


def test_tank_display_can_read_the_device_token() -> None:
    response = local_client(_app()).get("/dashboard/pairing")

    assert response.status_code == 200
    assert response.json()["token"] == "pairing-test-token"


def test_already_paired_device_can_read_the_device_token() -> None:
    response = lan_client(_app()).get(
        "/dashboard/pairing",
        headers={"Authorization": "Bearer pairing-test-token"},
    )

    assert response.status_code == 200
    assert response.json()["token"] == "pairing-test-token"


def test_wrong_token_from_lan_is_refused() -> None:
    response = lan_client(_app()).get(
        "/dashboard/pairing",
        headers={"Authorization": "Bearer not-the-token"},
    )

    assert response.status_code == 401
    assert "pairing-test-token" not in response.text


# ------------------------------------------------------------------ #
# Opening and closing the window                                       #
# ------------------------------------------------------------------ #


def test_lan_client_cannot_open_a_pairing_window() -> None:
    app = _app()

    response = lan_client(app).post("/dashboard/pairing/open")

    assert response.status_code == 403
    assert app.state.pairing_window.is_open() is False


def test_tank_display_can_open_and_close_a_pairing_window() -> None:
    app = _app()
    client = local_client(app)

    opened = client.post("/dashboard/pairing/open")
    assert opened.status_code == 200
    assert opened.json()["open"] is True
    assert app.state.pairing_window.is_open() is True

    closed = client.post("/dashboard/pairing/close")
    assert closed.status_code == 200
    assert closed.json()["open"] is False
    assert app.state.pairing_window.is_open() is False


def test_status_reports_window_state_without_the_token() -> None:
    app = _app()
    local_client(app).post("/dashboard/pairing/open")

    response = lan_client(app).get("/dashboard/status")

    pairing = response.json()["pairing"]
    assert pairing["pairing_open"] is True
    assert pairing["pairing_expires_in_seconds"] > 0
    assert "token" not in pairing
    assert "pairing-test-token" not in response.text


def test_window_expires(monkeypatch) -> None:
    clock = {"now": 1_000.0}
    monkeypatch.setattr("app.pairing.time.monotonic", lambda: clock["now"])
    window = PairingWindow(ttl_seconds=600)

    window.open()
    assert window.is_open() is True

    clock["now"] += 599
    assert window.is_open() is True

    clock["now"] += 2
    assert window.is_open() is False
    assert window.state()["expires_in_seconds"] is None


# ------------------------------------------------------------------ #
# First pairing                                                        #
# ------------------------------------------------------------------ #


def test_first_pairing_is_refused_while_the_window_is_closed() -> None:
    app = _app()

    response = lan_client(app).post("/auth/apple", json={"user_identifier": APPLE_USER})

    assert response.status_code == 403
    assert "not open for pairing" in response.json()["detail"]
    assert "pairing-test-token" not in response.text
    # A refused attempt must not claim the Tank.
    assert app.state.agent_store.get_kv("apple_user_identifier") is None


def test_first_pairing_succeeds_while_the_window_is_open() -> None:
    app = _app()
    local_client(app).post("/dashboard/pairing/open")

    response = lan_client(app).post("/auth/apple", json={"user_identifier": APPLE_USER})

    assert response.status_code == 200
    assert response.json()["device_token"] == "pairing-test-token"
    assert app.state.agent_store.get_kv("apple_user_identifier") == APPLE_USER


def test_pairing_window_is_spent_by_the_device_that_uses_it() -> None:
    app = _app()
    local_client(app).post("/dashboard/pairing/open")
    lan_client(app).post("/auth/apple", json={"user_identifier": APPLE_USER})

    assert app.state.pairing_window.is_open() is False

    # A second, different Apple ID cannot ride the same opening.
    response = lan_client(app).post("/auth/apple", json={"user_identifier": "999999.other"})
    assert response.status_code == 403


def test_paired_device_still_re_authenticates_without_a_window() -> None:
    app = _app()
    local_client(app).post("/dashboard/pairing/open")
    lan_client(app).post("/auth/apple", json={"user_identifier": APPLE_USER})
    assert app.state.pairing_window.is_open() is False

    again = lan_client(app).post("/auth/apple", json={"user_identifier": APPLE_USER})

    assert again.status_code == 200
    assert again.json()["device_token"] == "pairing-test-token"


def test_restart_closes_an_open_window() -> None:
    """The window is deliberately in-memory so it cannot outlive the process."""
    app = _app()
    local_client(app).post("/dashboard/pairing/open")
    assert app.state.pairing_window.is_open() is True

    restarted = _app()

    assert restarted.state.pairing_window.is_open() is False
