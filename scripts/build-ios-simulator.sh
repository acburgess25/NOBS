#!/usr/bin/env bash
# Build NOBS for the iOS Simulator without code signing.
# Use when automatic signing blocks Simulator work or for CI compile checks on a Mac.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
SIMULATOR_NAME="${NOBS_SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_OS="${NOBS_SIMULATOR_OS:-27.0}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}"

echo "Building NOBS for Simulator (${SIMULATOR_NAME}, iOS ${SIMULATOR_OS}) with CODE_SIGNING_ALLOWED=NO"
echo "DEVELOPER_DIR=${DEVELOPER_DIR}"

xcodebuild \
  -project NOBS.xcodeproj \
  -scheme NOBS \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Simulator build succeeded."
