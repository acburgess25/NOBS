"""Operator-present pairing gate for handing out the Tank device token.

The device token is the single credential that unlocks every authenticated Tank
route, so it must never be readable by anything that merely reached the API over
the network. Two rules enforce that:

* Reading the token (and opening a pairing window) requires a request that
  originated on the Tank host itself — the kiosk dashboard runs on the Tank, so
  it still works, while any phone or laptop on the LAN is refused.
* First pairing requires an explicitly opened, time-boxed window, so an Apple
  user identifier alone cannot claim an unpaired Tank.

The window lives in memory on purpose. Restarting the API closes it, which means
a forgotten open window cannot outlive the session that opened it.
"""

from __future__ import annotations

from ipaddress import ip_address
import time


def is_loopback_client(host: str | None) -> bool:
    """Return True only when `host` is a literal loopback address.

    `host` must come from the connection's peer address, never from a
    forwarded-for style header: those are caller-supplied and would let a remote
    request claim to be local. Non-address values (for example Starlette's
    "testclient" placeholder) are treated as remote.
    """
    if not host:
        return False
    try:
        return ip_address(host).is_loopback
    except ValueError:
        return False


class PairingWindow:
    """A time-boxed permission to pair one new device."""

    def __init__(self, ttl_seconds: int) -> None:
        self.ttl_seconds = ttl_seconds
        self._expires_at: float | None = None

    def open(self) -> None:
        self._expires_at = time.monotonic() + self.ttl_seconds

    def close(self) -> None:
        self._expires_at = None

    def is_open(self) -> bool:
        if self._expires_at is None:
            return False
        if time.monotonic() >= self._expires_at:
            # Expired windows close themselves so a stale window never grants
            # pairing after its deadline.
            self._expires_at = None
            return False
        return True

    def state(self) -> dict[str, object]:
        remaining = round(self._expires_at - time.monotonic()) if self.is_open() else None
        return {
            "open": remaining is not None,
            "expires_in_seconds": remaining,
            "ttl_seconds": self.ttl_seconds,
        }
