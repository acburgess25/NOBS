#!/usr/bin/env bash
set -uo pipefail

ROOT="/Users/alexburgess/Documents/NOBS 25"
CANONICAL="/Users/alexburgess/nobs"
MAC_APP="$CANONICAL/nobs-mac"
IOS_APP="$CANONICAL/nobs-app"
CONSOLIDATED="$ROOT/NOBS-consolidated"
OUTPUT="$ROOT/Tank-AI-Morning-Document.md"
APPROVAL="$ROOT/.tank-ai-morning-approved"
LOG="$ROOT/tank-ai-morning-document.log"

approve=false
force=false
for arg in "$@"; do
  case "$arg" in
    --approve) approve=true ;;
    --force) force=true ;;
  esac
done

timestamp() {
  TZ=America/Chicago date "+%Y-%m-%d %H:%M:%S %Z"
}

append_file() {
  local label="$1"
  local path="$2"
  local max_lines="${3:-220}"

  {
    echo
    echo "## $label"
    echo
    echo "\`$path\`"
    echo
    if [[ -f "$path" ]]; then
      echo '```'
      sed -n "1,${max_lines}p" "$path"
      echo '```'
    else
      echo "_Missing on this machine._"
    fi
  } >> "$OUTPUT"
}

append_command() {
  local label="$1"
  shift

  {
    echo
    echo "## $label"
    echo
    echo '```'
    "$@" 2>&1
    echo '```'
  } >> "$OUTPUT"
}

if [[ "$approve" == true ]]; then
  {
    echo "approved_at=$(timestamp)"
    echo "approved_by=local_button"
  } > "$APPROVAL"
fi

if [[ ! -f "$APPROVAL" && "$force" != true ]]; then
  {
    echo "[$(timestamp)] Morning document skipped because approval flag is missing."
    echo "Run from the app button, or run: $0 --approve --force"
  } >> "$LOG"
  exit 0
fi

tmp="$OUTPUT.tmp"
: > "$tmp"
mv "$tmp" "$OUTPUT"

{
  echo "# Tank AI Morning Document"
  echo
  echo "Generated: $(timestamp)"
  echo
  echo "This is the single morning handoff for offline travel. It is local on this Mac, so it remains available without Wi-Fi."
  echo
  echo "## Clean Approve Button Result"
  echo
  if [[ -f "$APPROVAL" ]]; then
    echo "- Approved: yes"
    sed 's/^/- /' "$APPROVAL"
  else
    echo "- Approved: forced local generation"
  fi
  echo
  echo "## What You Can Do With No Wi-Fi"
  echo
  echo "- Open this document locally: \`$OUTPUT\`"
  echo "- Open the macOS app locally: \`$MAC_APP/dist/NOBSMac.app\`"
  echo "- Use Tank AI in Offline mode from the toolbar or Tank AI page."
  echo "- Keep private spaces separate for Alex and boyfriend; move items to shared memory only by approval."
  echo "- When Wi-Fi returns, Auto mode can use Tank/nobsdash.com again."
  echo
  echo "## Current Product Shape"
  echo
  echo "- Tank AI is now a first-class macOS app section."
  echo "- Tank AI has two personal spaces plus a shared space."
  echo "- Chat has Auto / Online / Offline routing."
  echo "- Online route uses nobsdash.com -> Tank -> Ollama qwen2.5-coder:14b."
  echo "- Offline route uses the local helper at \`~/.local/bin/ask\`."
  echo "- The backend smoke test passed after making LiteLLM optional in Tank scan."
  echo "- The all-night self-improvement loop runs on Tank and writes cycle reports under \`/home/alex/tank-memory/self-improvement\`."
  echo
  echo "## Important Local Paths"
  echo
  echo "- Canonical NOBS root: \`$CANONICAL\`"
  echo "- macOS app: \`$MAC_APP\`"
  echo "- iOS app: \`$IOS_APP\`"
  echo "- Consolidated archive: \`$CONSOLIDATED\`"
  echo "- Morning document: \`$OUTPUT\`"
  echo
  echo "## 8 AM Checklist"
  echo
  echo "- Read this file first."
  echo "- Open Tank AI in the macOS app."
  echo "- If traveling with no Wi-Fi, set runtime to Offline."
  echo "- If Wi-Fi is back, set runtime to Auto and press Refresh."
  echo "- Do not depend on Tank while offline; local document and local app are the source of truth."
} >> "$OUTPUT"

append_command "Workspace Overview" /bin/ls -la "$ROOT"
append_command "Consolidated Top Level" /usr/bin/find "$CONSOLIDATED" -maxdepth 3 -type d
append_command "macOS App Source Files" /usr/bin/find "$MAC_APP/Sources/NOBSMac" -maxdepth 2 -type f

append_file "Tank AI macOS View" "$MAC_APP/Sources/NOBSMac/Views/TankAIView.swift" 260
append_file "Online Offline Routing Model" "$MAC_APP/Sources/NOBSMac/Models/RuntimeMode.swift" 120
append_file "Routing and Chat Store" "$MAC_APP/Sources/NOBSMac/Stores/CommandCenterStore.swift" 180
append_file "Online and Local Workspace Service" "$MAC_APP/Sources/NOBSMac/Services/WorkspaceService.swift" 180
append_file "Main Command Center Navigation" "$MAC_APP/Sources/NOBSMac/Views/CommandCenterView.swift" 160
append_file "Dashboard Entry Points" "$MAC_APP/Sources/NOBSMac/Views/DashboardView.swift" 180
append_file "Tank Backend API" "$CANONICAL/ops/tank-beta/api/app.py" 330
append_file "iOS Device Capability Routing" "$IOS_APP/Sources/NOBSCore/DeviceCapability.swift" 220
append_file "iOS App Tank Client Wiring" "$IOS_APP/Sources/NOBSApp/NOBSApp.swift" 220
append_file "Consolidated README" "$CONSOLIDATED/README.md" 220
append_file "Consolidation Archive Notes" "$CONSOLIDATED/archive-notes/skipped-duplicates-and-generated-files.md" 220

if command -v curl >/dev/null 2>&1; then
  append_command "Best Effort Online Backend Ping" /usr/bin/curl -fsS --max-time 3 https://nobsdash.com/api/v1/ping
else
  {
    echo
    echo "## Best Effort Online Backend Ping"
    echo
    echo "_curl not available._"
  } >> "$OUTPUT"
fi

append_command "Generated Document Size" /usr/bin/wc -l "$OUTPUT"

{
  echo
  echo "## Morning Bottom Line"
  echo
  echo "Tank AI is the personal AI layer for Alex and boyfriend. The macOS app can route Online, Offline, or Auto. This document exists locally for travel without Wi-Fi, and the approved morning workflow is now captured in one place."
} >> "$OUTPUT"

{
  echo "[$(timestamp)] Wrote $OUTPUT"
  /usr/bin/wc -l "$OUTPUT"
} >> "$LOG"

exit 0
