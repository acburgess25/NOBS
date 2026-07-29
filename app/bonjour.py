"""Private, token-free Bonjour advertisement for a NOBS Tank."""

from __future__ import annotations

import logging
import socket

try:
    from zeroconf import ServiceInfo, Zeroconf
except ImportError:  # pragma: no cover - only relevant to incomplete deployments
    ServiceInfo = None  # type: ignore[assignment,misc]
    Zeroconf = None  # type: ignore[assignment,misc]

LOGGER = logging.getLogger(__name__)
SERVICE_TYPE = "_nobs._tcp.local."


def preferred_lan_address() -> str | None:
    """Return the address used by the primary route, avoiding a second NIC."""
    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        probe.connect(("1.1.1.1", 80))
        address = probe.getsockname()[0]
        return address if not address.startswith("127.") else None
    except OSError:
        return None
    finally:
        probe.close()


class TankBonjourAdvertisement:
    def __init__(self, name: str, address: str | None = None) -> None:
        self.name = name
        self.address = address or preferred_lan_address()
        self._zeroconf: Zeroconf | None = None
        self._info: ServiceInfo | None = None

    def start(self) -> None:
        if Zeroconf is None or ServiceInfo is None:
            LOGGER.warning("Bonjour advertisement unavailable: install the zeroconf package")
            return
        if not self.address:
            LOGGER.warning("Bonjour advertisement unavailable: no LAN address was found")
            return
        self._info = ServiceInfo(
            type_=SERVICE_TYPE,
            name=f"{self.name}.{SERVICE_TYPE}",
            addresses=[socket.inet_aton(self.address)],
            port=8000,
            properties={"version": "1"},
            server=f"{self.name}.local.",
        )
        self._zeroconf = Zeroconf()
        self._zeroconf.register_service(self._info)
        LOGGER.info("Advertising NOBS Tank on %s via Bonjour", self.address)

    def close(self) -> None:
        if self._zeroconf is not None and self._info is not None:
            self._zeroconf.unregister_service(self._info)
        if self._zeroconf is not None:
            self._zeroconf.close()
        self._zeroconf = None
        self._info = None
