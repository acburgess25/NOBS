#!/usr/bin/env bash
# Run NOBSTests on the iOS Simulator without code signing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
SIMULATOR_NAME="${NOBS_SIMULATOR_NAME:-iPhone 17 Pro}"
SIMULATOR_OS="${NOBS_SIMULATOR_OS:-27.0}"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR_NAME},OS=${SIMULATOR_OS}"

echo "Running NOBSTests on Simulator (${SIMULATOR_NAME}, iOS ${SIMULATOR_OS})"
echo "DEVELOPER_DIR=${DEVELOPER_DIR}"

xcodebuild \
  -project NOBS.xcodeproj \
  -scheme NOBS \
  -destination "$DESTINATION" \
  -only-testing:NOBSTests \
  CODE_SIGNING_ALLOWED=NO \
  test

echo "NOBSTests succeeded."
