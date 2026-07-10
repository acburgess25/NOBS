#!/usr/bin/env python3
"""Validate App Store Connect API credentials."""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import httpx
import jwt


def main() -> int:
    key_id = os.environ.get("ASC_API_KEY_ID")
    issuer_id = os.environ.get("ASC_API_ISSUER_ID")
    key_path = os.environ.get("ASC_API_KEY_PATH")

    if not all([key_id, issuer_id, key_path]):
        print("Set ASC_API_KEY_ID, ASC_API_ISSUER_ID, and ASC_API_KEY_PATH", file=sys.stderr)
        return 1

    private_key = Path(key_path).expanduser().read_text(encoding="utf-8")
    token = jwt.encode(
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

    headers = {"Authorization": f"Bearer {token}"}
    with httpx.Client(timeout=30.0) as client:
        apps = client.get("https://api.appstoreconnect.apple.com/v1/apps?limit=5", headers=headers)
        certs = client.get(
            "https://api.appstoreconnect.apple.com/v1/certificates?limit=5",
            headers=headers,
        )

    if apps.status_code != 200:
        print(f"API apps check failed: {apps.status_code} {apps.text[:300]}", file=sys.stderr)
        return 1
    if certs.status_code != 200:
        print(f"API certificates check failed: {certs.status_code} {certs.text[:300]}", file=sys.stderr)
        return 1

    app_names = [
        item.get("attributes", {}).get("name", item.get("id", "?"))
        for item in apps.json().get("data", [])
    ]
    print(f"App Store Connect API OK (key {key_id})")
    print(f"Apps visible: {', '.join(app_names) or 'none'}")
    print(f"Certificates endpoint OK ({len(certs.json().get('data', []))} listed)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
