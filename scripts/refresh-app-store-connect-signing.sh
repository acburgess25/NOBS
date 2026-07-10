#!/usr/bin/env bash
# Re-sync signing assets via App Store Connect API (no manual .p12 export).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export ASC_API_KEY_ID="${ASC_API_KEY_ID:?ASC_API_KEY_ID}"
export ASC_API_ISSUER_ID="${ASC_API_ISSUER_ID:?ASC_API_ISSUER_ID}"
export ASC_API_KEY_PATH="${ASC_API_KEY_PATH:-$HOME/private_keys/AuthKey_${ASC_API_KEY_ID}.p8}"

if [[ ! -f "$ASC_API_KEY_PATH" ]]; then
  echo "Missing API key at $ASC_API_KEY_PATH" >&2
  echo "Set ASC_API_KEY_PATH or place AuthKey_<ID>.p8 in ~/private_keys/" >&2
  exit 1
fi

python3 -m pip install --user -q PyJWT cryptography httpx 2>/dev/null || true

echo "==> Validating App Store Connect API..."
python3 scripts/validate-asc-api.py

KEYCHAIN="${CI_KEYCHAIN:-${TMPDIR:-/tmp}/nobs-signing.keychain-db}"
PASSWORD="${CI_KEYCHAIN_PASSWORD:-nobs-ci-signing}"

echo "==> Preparing keychain..."
bash scripts/ci-prepare-keychain.sh "$KEYCHAIN" "$PASSWORD"

echo "==> Revoking stale development certificates..."
python3 scripts/ci-revoke-development-certs.py

echo "==> Creating development + distribution certificates..."
bash scripts/ci-ensure-signing-certs.sh "$KEYCHAIN" "$PASSWORD"

echo "==> Enabling required bundle capabilities (App Groups, Sign in with Apple)..."
python3 scripts/ci-enable-bundle-capabilities.py

echo "==> Refreshing provisioning profiles..."
bash scripts/ci-refresh-provisioning-profiles.sh

echo "==> Done. Signing identities:"
security find-identity -v -p codesigning "$KEYCHAIN"

echo ""
echo "To update GitHub secrets after rotating the API key in App Store Connect:"
echo "  gh secret set ASC_API_KEY_ID --body \"<KEY_ID>\""
echo "  gh secret set ASC_API_ISSUER_ID --body \"<ISSUER_ID>\""
echo "  gh secret set ASC_API_KEY_CONTENT < ~/private_keys/AuthKey_<KEY_ID>.p8"
