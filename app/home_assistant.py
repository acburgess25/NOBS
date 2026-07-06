from __future__ import annotations

import logging
from typing import Any
import httpx
from pydantic import SecretStr

logger = logging.getLogger(__name__)


class HomeAssistantClient:
    def __init__(self, url: str, token: SecretStr | None) -> None:
        self.url = url.rstrip("/")
        self.token = token

    @property
    def is_configured(self) -> bool:
        return bool(self.url and self.token and self.token.get_secret_value())

    def _headers(self) -> dict[str, str]:
        if not self.token:
            return {}
        return {
            "Authorization": f"Bearer {self.token.get_secret_value()}",
            "Content-Type": "application/json",
        }

    def list_devices(self, domain_filter: str | None = None) -> list[dict[str, Any]]:
        if not self.is_configured:
            raise ValueError("Home Assistant integration is not configured.")

        with httpx.Client(timeout=10.0) as client:
            response = client.get(f"{self.url}/api/states", headers=self._headers())
            response.raise_for_status()
            states = response.json()

        devices = []
        for item in states:
            entity_id = item.get("entity_id", "")
            domain = entity_id.split(".")[0] if "." in entity_id else ""

            if domain_filter and domain != domain_filter:
                continue

            friendly_name = item.get("attributes", {}).get("friendly_name", entity_id)
            devices.append(
                {
                    "entity_id": entity_id,
                    "name": friendly_name,
                    "state": item.get("state", "unknown"),
                    "domain": domain,
                }
            )
        return devices

    def call_service(
        self,
        domain: str,
        service: str,
        service_data: dict[str, Any],
    ) -> dict[str, Any]:
        if not self.is_configured:
            raise ValueError("Home Assistant integration is not configured.")

        with httpx.Client(timeout=10.0) as client:
            response = client.post(
                f"{self.url}/api/services/{domain}/{service}",
                headers=self._headers(),
                json=service_data,
            )
            response.raise_for_status()
            return {"status": "success", "response": response.json()}
