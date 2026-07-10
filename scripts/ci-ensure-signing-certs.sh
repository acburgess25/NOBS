#!/usr/bin/env bash
# Ensure CI keychain has Development + Distribution identities via App Store Connect API.
# Requires fastlane, ASC API key env vars, and an ephemeral keychain (no manual .p12 export).
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
  echo "fastlane is required for CI certificate provisioning" >&2
  exit 1
fi

import_wwdr() {
  local cert_url name
  for cert_url in \
    "https://www.apple.com/appleca/AppleIncRootCertificate.cer" \
    "https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer" \
    "https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer"
  do
    name="$(basename "$cert_url")"
    curl -fsSL -o "${RUNNER_TEMP:-/tmp}/${name}" "$cert_url"
    security import "${RUNNER_TEMP:-/tmp}/${name}" -k "$KEYCHAIN" -A \
      -T /usr/bin/codesign -T /usr/bin/security -T /usr/bin/xcodebuild || true
  done
}

identity_count() {
  local label="$1"
  security find-identity -v -p codesigning "$KEYCHAIN" | grep "$label" | grep -cv 'REVOKED' || true
}

has_valid_dev_identity() {
  [[ "$(identity_count 'iPhone Developer')" -ge 1 || "$(identity_count 'Apple Development')" -ge 1 ]]
}

has_valid_dist_identity() {
  [[ "$(identity_count 'Apple Distribution')" -ge 1 || "$(identity_count 'iPhone Distribution')" -ge 1 ]]
}

run_fastlane_cert() {
  local development="$1"
  local apple_certs="true"
  if [[ "$development" == "true" ]]; then
    apple_certs="false"
  fi
  set +e
  fastlane run cert \
    "development:${development}" \
    force:true \
    "generate_apple_certs:${apple_certs}" \
    keychain_path:"$KEYCHAIN" \
    keychain_password:"$KEYCHAIN_PASSWORD" \
    api_key_path:"$api_json"
  local status=$?
  set -e
  import_wwdr
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" || true
  return "$status"
}

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
import_wwdr

if ! has_valid_dev_identity; then
  echo "Revoking stale development certificates on the developer account..."
  python3 scripts/ci-revoke-development-certs.py
  echo "Creating iPhone Developer certificate via API..."
  run_fastlane_cert true || true
fi

if ! has_valid_dist_identity; then
  echo "Creating Apple Distribution certificate via API..."
  run_fastlane_cert false || true
fi

echo "Code signing identities in CI keychain:"
security find-identity -v -p codesigning "$KEYCHAIN"

if ! has_valid_dev_identity; then
  echo "No valid iPhone Developer / Apple Development identity in $KEYCHAIN" >&2
  exit 1
fi

if ! has_valid_dist_identity; then
  echo "No valid Apple Distribution identity in $KEYCHAIN (export may still use cloud signing)" >&2
fi
