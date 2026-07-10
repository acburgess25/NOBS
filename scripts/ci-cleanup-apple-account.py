#!/usr/bin/env python3
"""Remove non-NOBS signing assets from the Apple Developer account."""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path
from typing import Any

import httpx
import jwt

BASE = "https://api.appstoreconnect.apple.com/v1"
KEEP_APP_GROUPS = {"group.com.nobsdash.nobs"}
KEEP_BUNDLE_IDS = {"com.nobsdash.nobs", "com.nobsdash.nobs.widgets"}


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


class ASCClient:
    def __init__(self) -> None:
        self._client = httpx.Client(timeout=60.0)
        self._token = _token()
        self._token_at = time.time()

    def _headers(self) -> dict[str, str]:
        if time.time() - self._token_at > 1000:
            self._token = _token()
            self._token_at = time.time()
        return {"Authorization": f"Bearer {self._token}"}

    def get(self, path: str, *, params: dict[str, Any] | None = None) -> dict[str, Any]:
        response = self._client.get(f"{BASE}{path}", params=params, headers=self._headers())
        response.raise_for_status()
        return response.json()

    def delete(self, path: str) -> int:
        response = self._client.delete(f"{BASE}{path}", headers=self._headers())
        return response.status_code

    def post(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        response = self._client.post(f"{BASE}{path}", json=body, headers=self._headers())
        response.raise_for_status()
        return response.json()

    def paginate(self, path: str, *, params: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        items: list[dict[str, Any]] = []
        url: str | None = f"{BASE}{path}"
        query = dict(params or {})
        query.setdefault("limit", 200)
        while url:
            if url.startswith("http"):
                response = self._client.get(url, headers=self._headers())
            else:
                response = self._client.get(url, params=query, headers=self._headers())
            response.raise_for_status()
            payload = response.json()
            items.extend(payload.get("data", []))
            url = payload.get("links", {}).get("next")
            query = None
        return items

    def try_paginate(self, path: str, *, params: dict[str, Any] | None = None) -> list[dict[str, Any]] | None:
        try:
            return self.paginate(path, params=params)
        except httpx.HTTPStatusError as exc:
            if exc.response.status_code == 404:
                return None
            raise


def _keep_bundle(identifier: str) -> bool:
    return identifier in KEEP_BUNDLE_IDS


def list_account(client: ASCClient) -> None:
    bundles = client.paginate("/bundleIds")
    certs = client.paginate("/certificates")
    profiles = client.paginate("/profiles")
    apps = client.paginate("/apps")
    pass_types = client.try_paginate("/passTypeIds")
    merchants = client.try_paginate("/merchantIds")

    print("== Bundle IDs ==")
    for item in bundles:
        ident = item.get("attributes", {}).get("identifier", "?")
        mark = "KEEP" if _keep_bundle(ident) else "DELETE"
        print(f"  [{mark}] {ident} ({item['id']})")

    print("== App Groups ==")
    print(
        "  [MANUAL] App Groups are not exposed via App Store Connect API. "
        "Remove non-NOBS groups at "
        "https://developer.apple.com/account/resources/identifiers/list/applicationGroup"
    )

    if pass_types is not None:
        print("== Pass Type IDs ==")
        for item in pass_types:
            ident = item.get("attributes", {}).get("identifier", "?")
            mark = "KEEP" if _keep_bundle(ident) else "DELETE"
            print(f"  [{mark}] {ident} ({item['id']})")

    if merchants is not None:
        print("== Merchant IDs ==")
        for item in merchants:
            ident = item.get("attributes", {}).get("identifier", "?")
            print(f"  [DELETE] {ident} ({item['id']})")

    print("== Certificates ==")
    for item in certs:
        attrs = item.get("attributes", {})
        print(
            f"  [REVOKE] {attrs.get('certificateType', '?')} "
            f"{attrs.get('displayName', item['id'])} ({item['id']})"
        )

    print("== Provisioning Profiles ==")
    for item in profiles:
        attrs = item.get("attributes", {})
        print(f"  [DELETE] {attrs.get('name', item['id'])} ({item['id']})")

    print("== App Store Connect Apps ==")
    for item in apps:
        attrs = item.get("attributes", {})
        bundle = attrs.get("bundleId", "?")
        mark = "KEEP" if _keep_bundle(bundle) else "REVIEW"
        print(f"  [{mark}] {attrs.get('name', '?')} ({bundle})")


def cleanup(client: ASCClient, execute: bool) -> None:
    deleted_profiles = 0
    revoked_certs = 0
    deleted_bundles = 0
    deleted_pass_types = 0
    deleted_merchants = 0

    for item in client.paginate("/profiles"):
        profile_id = item["id"]
        name = item.get("attributes", {}).get("name", profile_id)
        if execute:
            status = client.delete(f"/profiles/{profile_id}")
            if status in {204, 200}:
                print(f"Deleted profile: {name}")
                deleted_profiles += 1
        else:
            print(f"[dry-run] delete profile: {name}")

    for item in client.paginate("/certificates"):
        cert_id = item["id"]
        name = item.get("attributes", {}).get("displayName", cert_id)
        if execute:
            status = client.delete(f"/certificates/{cert_id}")
            if status in {204, 200}:
                print(f"Revoked certificate: {name}")
                revoked_certs += 1
        else:
            print(f"[dry-run] revoke certificate: {name}")

    for item in client.paginate("/bundleIds"):
        ident = item.get("attributes", {}).get("identifier", "")
        if _keep_bundle(ident):
            print(f"Keeping bundle ID: {ident}")
            continue
        if execute:
            status = client.delete(f"/bundleIds/{item['id']}")
            if status in {204, 200}:
                print(f"Deleted bundle ID: {ident}")
                deleted_bundles += 1
        else:
            print(f"[dry-run] delete bundle ID: {ident}")

    pass_types = client.try_paginate("/passTypeIds")
    if pass_types:
        for item in pass_types:
            ident = item.get("attributes", {}).get("identifier", "")
            if _keep_bundle(ident):
                print(f"Keeping pass type ID: {ident}")
                continue
            if execute:
                status = client.delete(f"/passTypeIds/{item['id']}")
                if status in {204, 200}:
                    print(f"Deleted pass type ID: {ident}")
                    deleted_pass_types += 1
            else:
                print(f"[dry-run] delete pass type ID: {ident}")

    merchants = client.try_paginate("/merchantIds")
    if merchants:
        for item in merchants:
            ident = item.get("attributes", {}).get("identifier", "")
            if execute:
                status = client.delete(f"/merchantIds/{item['id']}")
                if status in {204, 200}:
                    print(f"Deleted merchant ID: {ident}")
                    deleted_merchants += 1
            else:
                print(f"[dry-run] delete merchant ID: {ident}")

    print(
        f"\nSummary: profiles={deleted_profiles}, certs={revoked_certs}, "
        f"bundles={deleted_bundles}, pass_types={deleted_pass_types}, merchants={deleted_merchants}"
    )
    print(
        "App Groups: remove manually at "
        "https://developer.apple.com/account/resources/identifiers/list/applicationGroup "
        f"(keep {', '.join(sorted(KEEP_APP_GROUPS))})"
    )


def ensure_nobs_resources(client: ASCClient, execute: bool) -> None:
    """Re-create NOBS bundle IDs if missing."""
    if not execute:
        print("[dry-run] ensure NOBS bundle IDs")
        return

    for ident, name in (("com.nobsdash.nobs", "NOBS"), ("com.nobsdash.nobs.widgets", "NOBS Widgets")):
        bundles = client.paginate("/bundleIds", params={"filter[identifier]": ident})
        if bundles:
            print(f"Bundle ID exists: {ident}")
            continue
        client.post(
            "/bundleIds",
            {
                "data": {
                    "type": "bundleIds",
                    "attributes": {"identifier": ident, "name": name, "platform": "IOS"},
                }
            },
        )
        print(f"Registered bundle ID: {ident}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="List account resources only")
    parser.add_argument("--execute", action="store_true", help="Perform deletions (default is dry-run)")
    args = parser.parse_args()

    for var in ("ASC_API_KEY_ID", "ASC_API_ISSUER_ID", "ASC_API_KEY_PATH"):
        if not os.environ.get(var):
            print(f"Missing {var}", file=sys.stderr)
            return 1

    client = ASCClient()

    if args.list:
        list_account(client)
        return 0

    print("=== BEFORE ===")
    list_account(client)
    print("\n=== CLEANUP ===")
    cleanup(client, execute=args.execute)
    if args.execute:
        print("\n=== ENSURE NOBS ===")
        ensure_nobs_resources(client, execute=True)
        print("\n=== AFTER ===")
        list_account(client)
    else:
        print("\nDry run only. Re-run with --execute to apply.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
