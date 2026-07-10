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
    return client.request(method, f"{BASE}{path}", params=params, json=json, headers=headers)


def _ensure_app_group(client: httpx.Client) -> None:
    response = _request(
        client,
        "GET",
        "/appGroups",
        params={"filter[identifier]": APP_GROUP, "limit": 1},
    )
    if response.status_code == 404:
        print(
            f"App Group {APP_GROUP} cannot be checked via API; ensure it exists in the "
            "Developer portal under Identifiers → App Groups"
        )
        return
    response.raise_for_status()
    if response.json().get("data"):
        print(f"App Group {APP_GROUP} already exists")
        return

    create = _request(
        client,
        "POST",
        "/appGroups",
        json={
            "data": {
                "type": "appGroups",
                "attributes": {
                    "identifier": APP_GROUP,
                    "name": "NOBS Shared",
                },
            }
        },
    )
    if create.status_code == 404:
        print(
            f"App Group {APP_GROUP} must be created manually in the Developer portal "
            "(Identifiers → App Groups)"
        )
        return
    if create.status_code in {201, 409}:
        print(f"Created App Group {APP_GROUP}")
        return
    create.raise_for_status()


def _ensure_bundle_id(client: httpx.Client, identifier: str, name: str) -> str:
    response = _request(
        client,
        "GET",
        "/bundleIds",
        params={"filter[identifier]": identifier, "limit": 1},
    )
    response.raise_for_status()
    data = response.json().get("data", [])
    if data:
        return data[0]["id"]

    create = _request(
        client,
        "POST",
        "/bundleIds",
        json={
            "data": {
                "type": "bundleIds",
                "attributes": {
                    "identifier": identifier,
                    "name": name,
                    "platform": "IOS",
                },
            }
        },
    )
    if create.status_code in {201, 409}:
        if create.status_code == 201:
            print(f"Registered bundle ID {identifier}")
            return create.json()["data"]["id"]
        # 409: created concurrently; fetch again
        retry = _request(
            client,
            "GET",
            "/bundleIds",
            params={"filter[identifier]": identifier, "limit": 1},
        )
        retry.raise_for_status()
        data = retry.json().get("data", [])
        if data:
            return data[0]["id"]

    create.raise_for_status()
    raise RuntimeError(f"Could not register bundle ID {identifier}")


def _has_capability(client: httpx.Client, bundle_id: str, capability_type: str) -> bool:
    response = _request(
        client,
        "GET",
        "/bundleIdCapabilities",
        params={"filter[bundleId]": bundle_id, "limit": 200},
    )
    if response.status_code in {400, 403, 404}:
        return False
    response.raise_for_status()
    return any(
        item.get("attributes", {}).get("capabilityType") == capability_type
        for item in response.json().get("data", [])
    )


def _delete_capability(client: httpx.Client, bundle_id: str, capability_type: str) -> None:
    response = _request(
        client,
        "GET",
        "/bundleIdCapabilities",
        params={"filter[bundleId]": bundle_id, "limit": 200},
    )
    if response.status_code in {400, 403, 404}:
        return
    response.raise_for_status()
    for item in response.json().get("data", []):
        if item.get("attributes", {}).get("capabilityType") != capability_type:
            continue
        delete = _request(client, "DELETE", f"/bundleIdCapabilities/{item['id']}")
        if delete.status_code in {204, 404}:
            print(f"Removed {capability_type} from bundle {bundle_id}")


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
    if response.status_code in {400, 403, 404}:
        print(
            f"Warning: could not enable {capability_type} for bundle {bundle_id} "
            f"({response.status_code}); verify in Developer portal"
        )
        return
    response.raise_for_status()


def main() -> int:
    with httpx.Client(timeout=30.0) as client:
        _ensure_app_group(client)
        app_id = _ensure_bundle_id(client, APP_BUNDLE, "NOBS")
        widget_id = _ensure_bundle_id(client, WIDGET_BUNDLE, "NOBS Widgets")

        app_group_settings = [
            {
                "key": "APP_GROUP_IDS",
                "options": [{"key": APP_GROUP, "enabled": True}],
            }
        ]

        _enable_capability(client, app_id, "APPLE_ID_AUTH")
        _delete_capability(client, app_id, "APP_GROUPS")
        _enable_capability(client, app_id, "APP_GROUPS", app_group_settings)
        _delete_capability(client, widget_id, "APP_GROUPS")
        _enable_capability(client, widget_id, "APP_GROUPS", app_group_settings)

    print("Bundle capabilities are configured for NOBS.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(f"Failed to enable bundle capabilities: {exc}", file=sys.stderr)
        raise
