from __future__ import annotations

from ipaddress import ip_address
import socket
from urllib.parse import urlparse


def is_public_http_url(url: str) -> bool:
    """Return True only for an http(s) URL whose host resolves off-host.

    Every address the host resolves to must be global. A hostname check alone is
    not enough: names under an attacker's control can point at loopback or a LAN
    address, and literal addresses can be written in forms a prefix match misses
    (`0.0.0.0`, `169.254.169.254`, integer-encoded IPv4, IPv6 link-local or
    unique-local). Resolving first and inspecting every answer covers all of
    those uniformly.

    This is the shared guard for anything that fetches a URL the user did not
    type — agent tools and the workplace browser sandbox both depend on it.
    """
    parsed = urlparse(url.strip())
    if parsed.scheme not in {"http", "https"}:
        return False
    host = (parsed.hostname or "").strip()
    if not host:
        return False
    try:
        resolved = socket.getaddrinfo(host, parsed.port or None, proto=socket.IPPROTO_TCP)
    except (socket.gaierror, UnicodeError, ValueError):
        # Unresolvable hosts are refused rather than handed to the fetcher, so a
        # DNS failure can never fall through to an unchecked request.
        return False
    if not resolved:
        return False
    for entry in resolved:
        address = entry[4][0]
        try:
            candidate = ip_address(address.split("%", 1)[0])
        except ValueError:
            return False
        if not candidate.is_global or candidate.is_multicast:
            return False
    return True


def local_lan_ip() -> str:
    """Best-effort LAN address for pairing links shown on the Tank display."""
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("10.255.255.255", 1))
        return probe.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        probe.close()


def tank_pairing_url() -> str:
    """The address a phone pairs against.

    One definition so the kiosk QR and the status payload can never advertise
    different addresses for the same Tank.
    """
    return f"http://{local_lan_ip()}:8000"
