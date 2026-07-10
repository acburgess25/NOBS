#!/usr/bin/env python3
"""Enable NOBS bundle capabilities required for provisioning profiles."""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path
from typing import Any

import httpx
import jwt

BASE = "https://api.appstoreconnect.apple.com/v1"
APP_BUNDLE = "com.nobsdash.nobs"
WIDGET_BUNDLE = "com.nobsdash.nobs.widgets"
APP_GROUP = "group.com.nobsdash.nobs"


def _token() -> str:
    key_id = os.environ["ASC_API_KEY_ID"]
    issuer_id = os.environ["ASC_API_ISSUER_ID"]
    key_path = Path(os.environ["ASC_API_KEY_PATH"]).expanduser()
    private_key = key_path.read_text(encoding="utf-8")
    return jwt.encode(
        {
            "iss": issuer_id,
            "iat": int(time.time()),
            "exp": int(time.time()) + 1200,
            "aud": "appstoreconnect-v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def _request(
    client: httpx.Client,
    method: str,
    path: str,
    *,
    params: dict[str, Any] | None = None,
    json: dict[str, Any] | None = None,
) -> httpx.Response:
    headers = {"Authorization": f"Bearer {_token()}"}
    response = client.request(method, f"{BASE}{path}", params=params, json=json, headers=headers)
    return response


def _bundle_id(client: httpx.Client, identifier: str) -> str:
    response = _request(
        client,
        "GET",
        "/bundleIds",
        params={"filter[identifier]": identifier, "limit": 1},
    )
    response.raise_for_status()
    data = response.json().get("data", [])
    if not data:
        raise RuntimeError(f"Bundle ID not found in App Store Connect: {identifier}")
    return data[0]["id"]


def _has_capability(client: httpx.Client, bundle_id: str, capability_type: str) -> bool:
    response = _request(client, "GET", f"/bundleIds/{bundle_id}/bundleIdCapabilities", params={"limit": 200})
    response.raise_for_status()
    return any(
        item.get("attributes", {}).get("capabilityType") == capability_type
        for item in response.json().get("data", [])
    )


def _enable_capability(
    client: httpx.Client,
    bundle_id: str,
    capability_type: str,
    settings: list[dict[str, Any]] | None = None,
) -> None:
    if _has_capability(client, bundle_id, capability_type):
        print(f"Capability {capability_type} already enabled for bundle {bundle_id}")
        return

    body = {
        "data": {
            "type": "bundleIdCapabilities",
            "attributes": {
                "capabilityType": capability_type,
                **({"settings": settings} if settings else {}),
            },
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_id}},
            },
        }
    }
    response = _request(client, "POST", "/bundleIdCapabilities", json=body)
    if response.status_code in {201, 409}:
        print(f"Enabled {capability_type} for bundle {bundle_id}")
        return
    response.raise_for_status()


def main() -> int:
    with httpx.Client(timeout=30.0) as client:
        app_id = _bundle_id(client, APP_BUNDLE)
        widget_id = _bundle_id(client, WIDGET_BUNDLE)

        app_group_settings = [
            {
                "key": "APP_GROUP_IDS",
                "options": [{"key": APP_GROUP, "enabled": True}],
            }
        ]

        _enable_capability(client, app_id, "APPLE_ID_AUTH")
        _enable_capability(client, app_id, "APP_GROUPS", app_group_settings)
        _enable_capability(client, widget_id, "APP_GROUPS", app_group_settings)

    print("Bundle capabilities are configured for NOBS.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to enable bundle capabilities: {exc}", file=sys.stderr)
        raise
