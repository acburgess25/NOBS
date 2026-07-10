#!/usr/bin/env bash
# Install or refresh the macOS LaunchAgent that runs the local Tank API.
#
# Usage (from repo root):
#   bash scripts/install-tank-launchagent.sh
#   bash scripts/install-tank-launchagent.sh --dry-run
#   TANK_ROOT=/path/to/checkout bash scripts/install-tank-launchagent.sh
#
# Writes ~/Library/LaunchAgents/com.nobs.tank.plist with WorkingDirectory and
# venv python pointing at the checkout you run this from (or TANK_ROOT).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TANK_ROOT="${TANK_ROOT:-$REPO_ROOT}"
TANK_PORT="${TANK_PORT:-8000}"
PLIST_LABEL="com.nobs.tank"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
DRY_RUN=0

usage() {
  cat <<'EOF'
Install or refresh the macOS LaunchAgent for the local Tank API.

Options:
  --dry-run   Print planned actions without changing anything
  --help      Show this help

Environment:
  TANK_ROOT   Tank working directory (default: repo root containing this script)
  TANK_PORT   API port (default: 8000)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

log() { printf '==> %s\n' "$*"; }
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

ensure_tank_root() {
  if [[ ! -d "$TANK_ROOT" ]]; then
    echo "error: TANK_ROOT does not exist: $TANK_ROOT" >&2
    exit 1
  fi
  if [[ ! -f "$TANK_ROOT/app/main.py" ]]; then
    echo "error: $TANK_ROOT does not look like a NOBS Tank checkout (missing app/main.py)" >&2
    exit 1
  fi
}

ensure_venv() {
  local python_bin="$TANK_ROOT/.venv/bin/python"
  if [[ ! -x "$python_bin" ]]; then
    log "Creating venv in $TANK_ROOT/.venv"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '[dry-run] cd %q && python3 scripts/dev.py setup\n' "$TANK_ROOT"
      return
    fi
    (cd "$TANK_ROOT" && python3 scripts/dev.py setup)
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] verify uvicorn in %s\n' "$python_bin"
    return
  fi

  if ! "$python_bin" -c "import uvicorn" 2>/dev/null; then
    log "Installing Tank dependencies into $TANK_ROOT/.venv"
    (cd "$TANK_ROOT" && "$python_bin" -m pip install -q -e ".[dev]")
  fi

  if ! "$python_bin" -c "import uvicorn" 2>/dev/null; then
    echo "error: uvicorn is still missing from $TANK_ROOT/.venv" >&2
    exit 1
  fi
}

write_plist() {
  local python_bin="$TANK_ROOT/.venv/bin/python"
  local out_log="$TANK_ROOT/nobs-tank.out.log"
  local err_log="$TANK_ROOT/nobs-tank.err.log"

  log "Writing $PLIST_PATH"
  log "  WorkingDirectory: $TANK_ROOT"
  log "  Python: $python_bin"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] write plist for %s on port %s\n' "$TANK_ROOT" "$TANK_PORT"
    return
  fi

  mkdir -p "$HOME/Library/LaunchAgents"
  cat >"$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${python_bin}</string>
        <string>-m</string>
        <string>uvicorn</string>
        <string>app.main:app</string>
        <string>--host</string>
        <string>0.0.0.0</string>
        <string>--port</string>
        <string>${TANK_PORT}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${TANK_ROOT}</string>
    <key>StandardOutPath</key>
    <string>${out_log}</string>
    <key>StandardErrorPath</key>
    <string>${err_log}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
}

load_launchagent() {
  local domain="gui/$(id -u)"
  local label="${domain}/${PLIST_LABEL}"

  if launchctl print "$label" >/dev/null 2>&1; then
    log "Reloading $PLIST_LABEL"
    run launchctl bootout "$domain" "$PLIST_PATH" 2>/dev/null || true
  fi

  log "Loading $PLIST_LABEL"
  run launchctl bootstrap "$domain" "$PLIST_PATH"
  run launchctl enable "$label"
  run launchctl kickstart -k "$label"
}

verify_tank() {
  local base="http://127.0.0.1:${TANK_PORT}"
  log "Health check: GET $base/health"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi

  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsS -m 3 "$base/health" >/dev/null 2>&1; then
      curl -fsS -m 5 "$base/health"
      echo
      return 0
    fi
    sleep 1
  done

  echo "warning: Tank did not pass health check on $base/health" >&2
  echo "Check logs: $TANK_ROOT/nobs-tank.err.log" >&2
  return 1
}

main() {
  ensure_tank_root
  ensure_venv
  write_plist
  load_launchagent
  verify_tank
  log "LaunchAgent installed for Tank root: $TANK_ROOT"
}

main
