#!/usr/bin/env bash
# Download fresh App Store provisioning profiles for NOBS targets.
set -euo pipefail

API_KEY_ID="${ASC_API_KEY_ID:?ASC_API_KEY_ID}"
API_KEY_ISSUER_ID="${ASC_API_ISSUER_ID:?ASC_API_ISSUER_ID}"
API_KEY_PATH="${ASC_API_KEY_PATH:-$HOME/private_keys/AuthKey_${API_KEY_ID}.p8}"

api_json="${RUNNER_TEMP:-/tmp}/asc-api-key.json"
python3 - <<PY
import json
from pathlib import Path

payload = {
    "key_id": "${API_KEY_ID}",
    "issuer_id": "${API_KEY_ISSUER_ID}",
    "key": Path("${API_KEY_PATH}").expanduser().read_text(encoding="utf-8"),
    "duration": 1200,
    "in_house": False,
}
Path("${api_json}").write_text(json.dumps(payload), encoding="utf-8")
PY

rm -rf "$HOME/Library/MobileDevice/Provisioning Profiles/"*
rm -rf "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/"* 2>/dev/null || true

if [[ -n "${CI_KEYCHAIN:-}" ]]; then
  security unlock-keychain -p "${CI_KEYCHAIN_PASSWORD:?CI_KEYCHAIN_PASSWORD}" "$CI_KEYCHAIN"
  security list-keychains -d user -s "$CI_KEYCHAIN" login.keychain-db
fi

dist_cert_id=""
if [[ -n "${CI_KEYCHAIN:-}" ]]; then
  dist_cert_id="$(
    security find-identity -v -p codesigning "$CI_KEYCHAIN" \
      | grep "Apple Distribution" \
      | grep -v REVOKED \
      | head -1 \
      | sed -E 's/^[[:space:]]*[0-9]+\) ([A-Z0-9]+) .*/\1/'
  )"
fi

if [[ -z "$dist_cert_id" ]]; then
  echo "No Apple Distribution certificate found in ${CI_KEYCHAIN:-system keychain}" >&2
  exit 1
fi

echo "Using distribution certificate ${dist_cert_id} for App Store profiles"

for app_id in com.nobsdash.nobs com.nobsdash.nobs.widgets; do
  echo "Refreshing App Store provisioning profile for ${app_id}..."
  fastlane run sigh \
    app_identifier:"${app_id}" \
    api_key_path:"${api_json}" \
    cert_id:"${dist_cert_id}" \
    force:true \
    skip_install:false
done
