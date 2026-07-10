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

has_dev_material() {
  security find-certificate -a -c "Apple Development" "$KEYCHAIN" >/dev/null 2>&1 \
    || security find-certificate -a -c "Apple Development: Alexander Burgess" "$KEYCHAIN" >/dev/null 2>&1 \
    || security find-certificate -a -c "iPhone Developer" "$KEYCHAIN" >/dev/null 2>&1 \
    || security find-certificate -a -c "iOS Development" "$KEYCHAIN" >/dev/null 2>&1
}

identity_count() {
  local label="$1"
  security find-identity -v -p codesigning "$KEYCHAIN" | grep -c "$label" || true
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

has_valid_dev_identity() {
  [[ "$(identity_count 'iPhone Developer')" -ge 1 || "$(identity_count 'Apple Development')" -ge 1 ]]
}

if ! has_valid_dev_identity; then
  echo "Revoking stale Apple Development certificates on the developer account..."
  python3 scripts/ci-revoke-development-certs.py

  echo "Creating Apple Development certificate in CI keychain..."
  set +e
  fastlane run cert \
    development:true \
    force:true \
    generate_apple_certs:false \
    keychain_path:"$KEYCHAIN" \
    keychain_password:"$KEYCHAIN_PASSWORD" \
    api_key_path:"$api_json"
  fastlane_status=$?
  set -e
  import_wwdr
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" || true
  if ! has_valid_dev_identity && ! has_dev_material; then
    echo "fastlane cert failed and no Apple Development certificate is available in $KEYCHAIN" >&2
    exit 1
  fi
fi

echo "Code signing identities in CI keychain:"
security find-identity -v -p codesigning "$KEYCHAIN"

dist_count="$(identity_count 'Apple Distribution')"
dev_ready=0
if has_valid_dev_identity; then
  dev_ready=1
fi

if [[ "$dist_count" -lt 1 || "$dev_ready" -lt 1 ]]; then
  echo "Expected valid Apple Distribution and iPhone Developer identities in $KEYCHAIN" >&2
  security find-identity -v -p codesigning "$KEYCHAIN" || true
  if security find-identity -v -p codesigning "$KEYCHAIN" | grep -q 'CSSMERR_TP_CERT_REVOKED'; then
    echo "The Apple Distribution certificate in DIST_CERT_P12 appears revoked. Regenerate it in Apple Developer and update the GitHub secret." >&2
  fi
  exit 1
fi
