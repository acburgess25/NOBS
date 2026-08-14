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
  # A local identity is necessary but not sufficient: the certificate must also
  # still exist in App Store Connect, or profile creation fails later. The
  # checker exits 2 when it cannot reach Apple, which we treat as "trust the
  # keychain" rather than revoking on a transient network error.
  if [[ "$(identity_count 'Apple Distribution')" -ge 1 || "$(identity_count 'iPhone Distribution')" -ge 1 ]]; then
    python3 "$(dirname "$0")/ci-check-distribution-cert.py"
    local status=$?
    [[ "$status" -eq 0 || "$status" -eq 2 ]]
  else
    return 1
  fi
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
    force:false \
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
security list-keychains -d user -s "$KEYCHAIN" login.keychain-db
import_wwdr

if ! has_valid_dev_identity; then
  echo "Creating iPhone Developer certificate via API..."
  run_fastlane_cert true || true
fi

if ! has_valid_dist_identity; then
  echo "Creating Apple Distribution certificate via API..."
  if ! run_fastlane_cert false; then
    # Do not revoke automatically. Creation fails almost entirely because the
    # team is at Apple's distribution-certificate limit, and the previous
    # behaviour here was to revoke *every* distribution certificate on the
    # team and mint a replacement. Revocation is not local to CI: it
    # invalidates that certificate everywhere it is installed, including a
    # developer's own Mac, and it is not reversible. Destroying shared signing
    # material to recover a build is the machine making a call that belongs to
    # a person, so fail with instructions instead.
    cat >&2 <<'MESSAGE'
Could not create an Apple Distribution certificate.

This usually means the team is at Apple's distribution-certificate limit
(three on the standard Apple Developer Program). Note that this workflow
creates a new certificate on every run, because the CI keychain is rebuilt
empty each time and fastlane cannot find the existing private key.

To recover, in Certificates, Identifiers & Profiles → Certificates:
  1. Delete surplus Apple Distribution certificates, keeping the one in use.
  2. Re-run this workflow.

Certificates are deliberately NOT revoked automatically here: revoking
invalidates the certificate on every machine that has it, and that is a
decision for a person rather than for CI. To revoke intentionally, run
scripts/ci-revoke-distribution-certs.py yourself.
MESSAGE
    exit 1
  fi
fi

echo "Code signing identities in CI keychain:"
security find-identity -v -p codesigning "$KEYCHAIN"

if ! has_valid_dev_identity; then
  echo "No valid iPhone Developer / Apple Development identity in $KEYCHAIN" >&2
  exit 1
fi

if ! has_valid_dist_identity; then
  echo "No valid Apple Distribution identity in $KEYCHAIN" >&2
  exit 1
fi
