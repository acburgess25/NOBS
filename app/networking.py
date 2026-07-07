from __future__ import annotations

import socket


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
