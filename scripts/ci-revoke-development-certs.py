#!/usr/bin/env python3
"""Revoke Apple Development certificates via App Store Connect API."""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import httpx
import jwt


def _token() -> str:
    key_id = os.environ["ASC_API_KEY_ID"]
    issuer_id = os.environ["ASC_API_ISSUER_ID"]
    key_path = Path(os.environ["ASC_API_KEY_PATH"]).expanduser()
    private_key = key_path.read_text(encoding="utf-8")
    payload = {
        "iss": issuer_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + 1200,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(
        payload,
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def main() -> int:
    token = _token()
    headers = {"Authorization": f"Bearer {token}"}
    base = "https://api.appstoreconnect.apple.com/v1"

    with httpx.Client(timeout=30.0) as client:
        response = client.get(
            f"{base}/certificates",
            params={"filter[certificateType]": "DEVELOPMENT"},
            headers=headers,
        )
        response.raise_for_status()
        certs = response.json().get("data", [])

        if not certs:
            print("No Apple Development certificates to revoke.")
            return 0

        for cert in certs:
            cert_id = cert["id"]
            name = cert.get("attributes", {}).get("displayName", cert_id)
            delete = client.delete(f"{base}/certificates/{cert_id}", headers=headers)
            delete.raise_for_status()
            print(f"Revoked development certificate {cert_id} ({name})")

    print(f"Revoked {len(certs)} development certificate(s).")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001 - CI script should print a clear failure
        print(f"Failed to revoke development certificates: {exc}", file=sys.stderr)
        raise
