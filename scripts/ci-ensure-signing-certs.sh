#!/usr/bin/env bash
# Ensure CI keychain has Apple Development + Distribution identities for archive.
# Requires fastlane, App Store Connect API key env vars, and imported distribution .p12.
set -euo pipefail

KEYCHAIN="${1:?keychain path}"
KEYCHAIN_PASSWORD="${2:?keychain password}"
API_KEY_ID="${ASC_API_KEY_ID:?ASC_API_KEY_ID}"
API_KEY_ISSUER_ID="${ASC_API_ISSUER_ID:?ASC_API_ISSUER_ID}"
API_KEY_PATH="${ASC_API_KEY_PATH:-$HOME/private_keys/AuthKey_${API_KEY_ID}.p8}"
case "$API_KEY_PATH" in
  "~/"*) API_KEY_PATH="$HOME/${API_KEY_PATH#~/}" ;;
esac

if [[ ! -f "$API_KEY_PATH" ]]; then
  echo "App Store Connect API key not found at $API_KEY_PATH" >&2
  exit 1
fi

if ! command -v fastlane >/dev/null; then
  echo "fastlane is required for CI development certificate provisioning" >&2
  exit 1
fi

api_json="${RUNNER_TEMP:-/tmp}/asc-api-key.json"
python3 - <<PY
import json
from pathlib import Path

payload = {
    "key_id": "${API_KEY_ID}",
    "issuer_id": "${API_KEY_ISSUER_ID}",
    "key": Path("${API_KEY_PATH}").read_text(encoding="utf-8"),
    "duration": 1200,
    "in_house": False,
}
Path("${api_json}").write_text(json.dumps(payload), encoding="utf-8")
PY

security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN"

echo "Creating Apple Development certificate in CI keychain (revokes orphaned portal cert if needed)..."
fastlane run cert \
  development:true \
  force:true \
  generate_apple_certs:true \
  keychain_path:"$KEYCHAIN" \
  keychain_password:"$KEYCHAIN_PASSWORD" \
  api_key_path:"$api_json"

echo "Code signing identities in CI keychain:"
security find-identity -v -p codesigning "$KEYCHAIN"

dist_count="$(security find-identity -v -p codesigning "$KEYCHAIN" | grep -c 'Apple Distribution' || true)"
dev_count="$(security find-identity -v -p codesigning "$KEYCHAIN" | grep -c 'Apple Development' || true)"

if [[ "$dist_count" -lt 1 || "$dev_count" -lt 1 ]]; then
  echo "Expected both Apple Distribution and Apple Development identities in $KEYCHAIN" >&2
  exit 1
fi
