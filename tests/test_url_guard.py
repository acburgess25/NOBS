"""The shared fetch guard keeps auto-running tools off the local network.

`read_url` is read-only, so it executes without approval, and the URL it is
given can be shaped by whatever the model just read. These tests pin the host
rules so a future change cannot quietly turn it back into a general fetcher.
"""

import socket
from unittest.mock import patch

import pytest

from app.networking import is_public_http_url


def _resolves_to(*addresses: str):
    """Patch DNS so host rules are tested without touching the network."""

    def fake_getaddrinfo(host, port, *args, **kwargs):
        if not addresses:
            raise socket.gaierror(-2, "Name or service not known")
        return [
            (socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP, "", (address, port or 80))
            for address in addresses
        ]

    return patch("app.networking.socket.getaddrinfo", side_effect=fake_getaddrinfo)


@pytest.mark.parametrize(
    "url",
    [
        "https://example.com/article",
        "http://example.com",
        "https://example.com:8443/path?q=1",
    ],
)
def test_public_urls_are_allowed(url: str) -> None:
    with _resolves_to("93.184.216.34"):
        assert is_public_http_url(url) is True


@pytest.mark.parametrize(
    "scheme_url",
    [
        "file:///etc/passwd",
        "ftp://example.com/x",
        "gopher://example.com",
        "data:text/plain,hello",
        "//example.com/no-scheme",
        "",
    ],
)
def test_non_http_schemes_are_refused(scheme_url: str) -> None:
    assert is_public_http_url(scheme_url) is False


@pytest.mark.parametrize(
    "address",
    [
        "127.0.0.1",  # loopback — the Tank's own API
        "0.0.0.0",
        "10.0.0.4",  # RFC1918
        "192.168.1.10",  # typical Home Assistant host
        "172.16.0.9",
        "169.254.169.254",  # link-local / cloud metadata
        "::1",
        "fd00::1",  # IPv6 unique-local
        "fe80::1",  # IPv6 link-local
        "224.0.0.1",  # multicast
    ],
)
def test_private_and_special_addresses_are_refused(address: str) -> None:
    """A hostname is refused on the address it resolves to, not on its spelling."""
    with _resolves_to(address):
        assert is_public_http_url(f"http://looks-harmless.example.com/{address}") is False


def test_literal_private_addresses_are_refused() -> None:
    with _resolves_to("127.0.0.1"):
        assert is_public_http_url("http://127.0.0.1:8000/dashboard/status") is False


def test_integer_encoded_loopback_is_refused() -> None:
    """http://2130706433/ is 127.0.0.1 written as an integer."""
    with _resolves_to("127.0.0.1"):
        assert is_public_http_url("http://2130706433/") is False


def test_host_resolving_to_both_public_and_private_is_refused() -> None:
    """Every answer must be public, or the fetch could land on the private one."""
    with _resolves_to("93.184.216.34", "127.0.0.1"):
        assert is_public_http_url("http://split-horizon.example.com") is False


def test_unresolvable_host_is_refused() -> None:
    with _resolves_to():
        assert is_public_http_url("http://does-not-exist.invalid") is False


def test_empty_host_is_refused() -> None:
    assert is_public_http_url("http:///path-only") is False
