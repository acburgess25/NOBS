#!/usr/bin/env bash
# Download fresh development provisioning profiles that include the CI certificate.
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

for app_id in com.nobsdash.nobs com.nobsdash.nobs.widgets; do
  echo "Refreshing provisioning profile for ${app_id}..."
  fastlane run sigh \
    app_identifier:"${app_id}" \
    api_key_path:"${api_json}" \
    force:true \
    skip_install:false \
    development:true
done
