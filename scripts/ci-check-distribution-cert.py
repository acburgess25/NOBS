#!/usr/bin/env python3
"""Exit 0 if App Store Connect still holds an Apple Distribution certificate.

A signing identity in the local keychain is not proof that the certificate is
still valid: revoking or deleting it in App Store Connect leaves the local copy
untouched. Provisioning-profile creation asks Apple, not the keychain, so a
stale local identity makes the pipeline skip re-issuing and then fail later
with "No Apple Distribution certificate found in App Store Connect".

Usage:
    python scripts/ci-check-distribution-cert.py   # 0 = present, 1 = missing

Environment:
    ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_PATH
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import httpx
import jwt

BASE = "https://api.appstoreconnect.apple.com/v1"
DISTRIBUTION_TYPES = {"DISTRIBUTION", "IOS_DISTRIBUTION"}


def _token() -> str:
    key_id = os.environ["ASC_API_KEY_ID"]
    issuer_id = os.environ["ASC_API_ISSUER_ID"]
    key_path = Path(os.environ["ASC_API_KEY_PATH"]).expanduser()
    return jwt.encode(
        {
            "iss": issuer_id,
            "iat": int(time.time()),
            "exp": int(time.time()) + 600,
            "aud": "appstoreconnect-v1",
        },
        key_path.read_text(encoding="utf-8"),
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def main() -> int:
    try:
        headers = {"Authorization": f"Bearer {_token()}"}
    except KeyError as missing:
        print(f"Missing environment variable: {missing}", file=sys.stderr)
        return 2
    except OSError as error:
        print(f"Could not read the API key: {error}", file=sys.stderr)
        return 2

    try:
        with httpx.Client(timeout=30.0) as client:
            response = client.get(f"{BASE}/certificates?limit=200", headers=headers)
            response.raise_for_status()
            data = response.json().get("data", [])
    except httpx.HTTPError as error:
        # Do not claim a certificate is missing because the network failed;
        # that would trigger an unnecessary revoke-and-reissue cycle.
        print(f"Could not reach App Store Connect: {error}", file=sys.stderr)
        return 2

    found = [
        item
        for item in data
        if (item.get("attributes") or {}).get("certificateType") in DISTRIBUTION_TYPES
    ]
    if found:
        name = (found[0].get("attributes") or {}).get("name", "Apple Distribution")
        print(f"App Store Connect holds {len(found)} distribution certificate(s): {name}")
        return 0

    print("App Store Connect holds no Apple Distribution certificate")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
