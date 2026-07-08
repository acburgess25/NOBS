from __future__ import annotations

import ipaddress
import socket
from urllib.parse import urlparse


class UnsafeURLError(ValueError):
    pass


def assert_public_http_url(url: str) -> None:
    """Reject URLs that target private, loopback, or link-local hosts (SSRF guard)."""
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        raise UnsafeURLError("Only HTTP and HTTPS URLs are allowed")
    hostname = parsed.hostname
    if not hostname:
        raise UnsafeURLError("URL must include a hostname")
    if hostname.lower() in {"localhost"}:
        raise UnsafeURLError("Localhost URLs are not allowed")

    try:
        addr_infos = socket.getaddrinfo(hostname, None)
    except socket.gaierror as error:
        raise UnsafeURLError(f"Could not resolve hostname: {hostname}") from error

    for info in addr_infos:
        address = info[4][0]
        try:
            ip = ipaddress.ip_address(address)
        except ValueError:
            continue
        if (
            ip.is_private
            or ip.is_loopback
            or ip.is_link_local
            or ip.is_reserved
            or ip.is_multicast
        ):
            raise UnsafeURLError("Private or local network URLs are not allowed")
