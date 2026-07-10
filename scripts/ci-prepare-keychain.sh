#!/usr/bin/env bash
# Create an ephemeral CI keychain with Apple intermediate certificates.
set -euo pipefail

KEYCHAIN="${1:?keychain path}"
KEYCHAIN_PASSWORD="${2:?keychain password}"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security list-keychains -d user -s "$KEYCHAIN"

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
