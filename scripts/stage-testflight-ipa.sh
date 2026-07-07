#!/usr/bin/env bash
# Build a release IPA locally and stage it for the upload-only TestFlight workflow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE_DIR="${NOBS_IPA_STAGE_DIR:-$HOME/nobs-build}"
ARCHIVE_PATH="${STAGE_DIR}/NOBS.xcarchive"
EXPORT_DIR="${STAGE_DIR}/export"
EXPORT_OPTIONS="${ROOT}/ExportOptions.plist"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
export DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-K853LKQLAS}"

mkdir -p "$STAGE_DIR"

auth=()
if [[ -n "${ASC_API_KEY_ID:-}" && -f "${ASC_API_KEY_PATH:-}" ]]; then
  auth=(
    -allowProvisioningUpdates
    -authenticationKeyPath "$ASC_API_KEY_PATH"
    -authenticationKeyID "$ASC_API_KEY_ID"
    -authenticationKeyIssuerID "${ASC_API_ISSUER_ID:?}"
  )
fi

archive_args=(
  -project "$ROOT/NOBS.xcodeproj"
  -scheme NOBS
  -configuration Release
  -destination 'generic/platform=iOS'
  -archivePath "$ARCHIVE_PATH"
  CODE_SIGN_STYLE=Automatic
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
)
if ((${#auth[@]})); then
  archive_args=("${auth[@]}" "${archive_args[@]}")
fi

xcodebuild archive "${archive_args[@]}"

export_args=(
  -archivePath "$ARCHIVE_PATH"
  -exportOptionsPlist "$EXPORT_OPTIONS"
  -exportPath "$EXPORT_DIR"
)
if ((${#auth[@]})); then
  export_args=("${auth[@]}" "${export_args[@]}")
fi

xcodebuild -exportArchive "${export_args[@]}"

cp "$EXPORT_DIR/NOBS.ipa" "$STAGE_DIR/NOBS.ipa"
echo "Staged IPA: $STAGE_DIR/NOBS.ipa"
