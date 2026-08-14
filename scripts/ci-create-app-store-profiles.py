#!/usr/bin/env python3
"""Create and install App Store provisioning profiles via App Store Connect API."""

from __future__ import annotations

import base64
import os
import plistlib
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

import httpx
import jwt

BASE = "https://api.appstoreconnect.apple.com/v1"
PROFILES = [
    ("com.nobsdash.nobs", "com.nobsdash.nobs AppStore"),
    ("com.nobsdash.nobs.widgets", "com.nobsdash.nobs.widgets AppStore"),
]


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


def _bundle_id(client: ASCClient, identifier: str) -> str:
    payload = client.get("/bundleIds", params={"filter[identifier]": identifier, "limit": 1})
    data = payload.get("data", [])
    if not data:
        raise RuntimeError(f"Bundle ID not found: {identifier}")
    return data[0]["id"]


def _distribution_certificate_id(client: ASCClient) -> str:
    for cert_type in ("IOS_DISTRIBUTION", "DISTRIBUTION"):
        for item in client.paginate("/certificates", params={"filter[certificateType]": cert_type}):
            if item.get("attributes", {}).get("expirationDate"):
                print(
                    "Using distribution certificate "
                    f"{item['id']} ({item.get('attributes', {}).get('displayName', '?')})"
                )
                return item["id"]
    raise RuntimeError("No Apple Distribution certificate found in App Store Connect")


def _delete_existing_profiles(client: ASCClient, profile_name: str) -> None:
    """Clear every profile holding this name, whatever its type or state.

    App Store Connect requires profile names to be unique across the whole
    team, not per profile type. Filtering the sweep to `IOS_APP_STORE` left a
    same-named development, ad-hoc, or expired profile in place, and the
    following create then failed with `409 Conflict` on a name that looked
    already deleted. Matching on the name alone is what the uniqueness rule
    actually is. The names in `PROFILES` are bundle-namespaced, so this cannot
    reach an unrelated profile.
    """
    for item in client.paginate("/profiles"):
        attrs = item.get("attributes", {})
        if attrs.get("name") != profile_name:
            continue
        profile_id = item["id"]
        status = client.delete(f"/profiles/{profile_id}")
        if status in {204, 404}:
            print(
                f"Deleted existing profile {profile_name} "
                f"({profile_id}, type {attrs.get('profileType', '?')})"
            )


def _decode_profile(content: bytes) -> dict[str, Any]:
    with tempfile.NamedTemporaryFile(suffix=".mobileprovision", delete=False) as handle:
        handle.write(content)
        temp_path = handle.name
    try:
        result = subprocess.run(
            ["security", "cms", "-D", "-i", temp_path],
            capture_output=True,
            check=True,
        )
    finally:
        Path(temp_path).unlink(missing_ok=True)
    return plistlib.loads(result.stdout)


def _create_profile(
    client: ASCClient,
    *,
    bundle_identifier: str,
    profile_name: str,
    bundle_resource_id: str,
    certificate_id: str,
) -> bytes:
    body = {
        "data": {
            "type": "profiles",
            "attributes": {
                "name": profile_name,
                "profileType": "IOS_APP_STORE",
            },
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle_resource_id}},
                "certificates": {"data": [{"type": "certificates", "id": certificate_id}]},
            },
        }
    }
    try:
        created = client.post("/profiles", body)
    except httpx.HTTPStatusError as error:
        if error.response.status_code != 409:
            raise
        # A conflict here is always the name, and the sweep above should have
        # cleared it. Say what to look at instead of surfacing a raw traceback.
        raise RuntimeError(
            f"App Store Connect rejected profile {profile_name!r} as a conflict. "
            "A profile with that exact name still exists on the team — check "
            "Certificates, Identifiers & Profiles → Profiles for every profile "
            "type, including expired ones, and delete it before re-running."
        ) from error
    profile_id = created["data"]["id"]
    fetched = client.get(f"/profiles/{profile_id}")
    content_b64 = fetched["data"]["attributes"].get("profileContent")
    if not content_b64:
        raise RuntimeError(f"Profile {profile_name} has no downloadable content")
    content = base64.b64decode(content_b64)
    plist_data = _decode_profile(content)
    entitlements = plist_data.get("Entitlements", {})
    app_groups = entitlements.get("com.apple.security.application-groups", [])
    print(f"Created profile {profile_name} (UUID {plist_data.get('UUID', '?')})")
    if bundle_identifier.endswith(".widgets"):
        if not app_groups:
            raise RuntimeError(
                f"Profile {profile_name} is missing App Groups entitlements; "
                "assign group.com.nobsdash.nobs to com.nobsdash.nobs.widgets in Developer portal"
            )
        print(f"  App Groups: {', '.join(app_groups)}")
    return content


def _install_profile(content: bytes) -> None:
    plist_data = _decode_profile(content)
    profile_uuid = plist_data["UUID"]
    install_dir = Path.home() / "Library/MobileDevice/Provisioning Profiles"
    install_dir.mkdir(parents=True, exist_ok=True)
    destination = install_dir / f"{profile_uuid}.mobileprovision"
    destination.write_bytes(content)
    print(f"Installed {destination}")


def main() -> int:
    client = ASCClient()
    certificate_id = _distribution_certificate_id(client)

    install_dir = Path.home() / "Library/MobileDevice/Provisioning Profiles"
    if install_dir.exists():
        for path in install_dir.glob("*.mobileprovision"):
            path.unlink()

    xcode_profiles = Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles"
    if xcode_profiles.exists():
        for path in xcode_profiles.glob("*.mobileprovision"):
            path.unlink()

    for bundle_identifier, profile_name in PROFILES:
        bundle_resource_id = _bundle_id(client, bundle_identifier)
        _delete_existing_profiles(client, profile_name)
        content = _create_profile(
            client,
            bundle_identifier=bundle_identifier,
            profile_name=profile_name,
            bundle_resource_id=bundle_resource_id,
            certificate_id=certificate_id,
        )
        _install_profile(content)

    print("App Store provisioning profiles are ready.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"Failed to create App Store profiles: {exc}", file=sys.stderr)
        raise
