#!/usr/bin/env bash
# Reset Tank to a clean first-time client state.
#
# Stops the Tank API, backs up client data, wipes pairing/devices/sessions,
# re-initializes an empty agent database schema, clears the device token, and
# restarts the service.
#
# Usage (from repo root):
#   bash scripts/reset-tank-fresh.sh              # local Tank (auto-detect root)
#   bash scripts/reset-tank-fresh.sh --dry-run    # show actions only
#   TANK_ROOT=/path/to/tank bash scripts/reset-tank-fresh.sh
#   bash scripts/reset-tank-fresh.sh --remote     # homelab host (TANK_HOST=tank)
#
# Does not touch iPhone Keychain, Apple ID, or secrets outside the Tank tree.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TANK_HOST="${TANK_HOST:-tank}"
TANK_PORT="${TANK_PORT:-8000}"
DRY_RUN=0
REMOTE=0

usage() {
  cat <<'EOF'
Reset Tank to a first-time client state.

Options:
  --dry-run   Print planned actions without changing anything
  --remote    Reset the homelab Tank over SSH (systemctl --user nobs-api)
  --help      Show this help

Environment:
  TANK_ROOT   Tank working directory (data/, .env). Auto-detected when unset.
  TANK_HOST   SSH host for --remote (default: tank)
  TANK_PORT   API port for health checks (default: 8000)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --remote) REMOTE=1 ;;
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

detect_tank_root() {
  if [[ -n "${TANK_ROOT:-}" ]]; then
    printf '%s' "$TANK_ROOT"
    return
  fi

  local pid cwd
  pid="$(lsof -tiTCP:"$TANK_PORT" -sTCP:LISTEN 2>/dev/null | head -1 || true)"
  if [[ -n "$pid" ]]; then
    cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1 || true)"
    if [[ -n "$cwd" && -d "$cwd" ]]; then
      printf '%s' "$cwd"
      return
    fi
  fi

  local plist="$HOME/Library/LaunchAgents/com.nobs.tank.plist"
  if [[ -f "$plist" ]]; then
  cwd="$(/usr/libexec/PlistBuddy -c 'Print :WorkingDirectory' "$plist" 2>/dev/null || true)"
    if [[ -n "$cwd" && -d "$cwd" ]]; then
      printf '%s' "$cwd"
      return
    fi
  fi

  printf '%s' "$REPO_ROOT"
}

CLIENT_DATA_PATHS=(
  "data/nobs-agent.db"
  "data/nobs-agent.db-shm"
  "data/nobs-agent.db-wal"
  "data/agent-workspace"
  "data/dream-team-sandbox"
  "data/dream-team/active"
  "data/workplace/screenshots"
  "nobs.db"
)

CLIENT_DATA_DIRS=(
  "data/agent-workspace"
  "data/dream-team-sandbox"
  "data/dream-team/active"
  "data/workplace/screenshots"
)

stop_local_tank() {
  if systemctl --user is-active nobs-api >/dev/null 2>&1; then
    log "Stopping nobs-api (systemd --user)"
    run systemctl --user stop nobs-api
    return
  fi

  local domain="gui/$(id -u)"
  local label="${domain}/com.nobs.tank"
  local plist="$HOME/Library/LaunchAgents/com.nobs.tank.plist"
  if launchctl print "$label" >/dev/null 2>&1; then
    log "Stopping com.nobs.tank LaunchAgent"
    run launchctl bootout "$domain" "$plist" 2>/dev/null || run launchctl stop "$label" 2>/dev/null || true
    sleep 2
    return
  fi

  local pid
  pid="$(lsof -tiTCP:"$TANK_PORT" -sTCP:LISTEN 2>/dev/null | head -1 || true)"
  if [[ -n "$pid" ]]; then
    log "Stopping uvicorn listener on :$TANK_PORT (pid $pid)"
    run kill -TERM "$pid"
    sleep 2
  fi
}

start_local_tank() {
  if systemctl --user cat nobs-api >/dev/null 2>&1; then
    log "Starting nobs-api (systemd --user)"
    run systemctl --user start nobs-api
    return
  fi

  local domain="gui/$(id -u)"
  local label="${domain}/com.nobs.tank"
  local plist="$HOME/Library/LaunchAgents/com.nobs.tank.plist"
  if [[ -f "$plist" ]]; then
    log "Starting com.nobs.tank LaunchAgent"
    run launchctl bootstrap "$domain" "$plist" 2>/dev/null || true
    run launchctl kickstart -k "$label" 2>/dev/null || true
    if [[ "$DRY_RUN" -eq 0 ]] && curl -fsS -m 3 "http://127.0.0.1:$TANK_PORT/health" >/dev/null 2>&1; then
      return
    fi
    log "LaunchAgent did not pass health check; falling back to direct uvicorn"
  fi

  local root="${TANK_ROOT_DETECTED:-$REPO_ROOT}"
  local python_bin="$root/.venv/bin/python"
  if [[ ! -x "$python_bin" ]]; then
    python_bin="$REPO_ROOT/.venv/bin/python"
  fi
  if [[ -x "$python_bin" ]] && "$python_bin" -c "import uvicorn" 2>/dev/null; then
    log "Starting uvicorn from $root (.venv fallback)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '[dry-run] cd %q && %q -m uvicorn app.main:app --host 0.0.0.0 --port %s &\n' \
        "$root" "$python_bin" "$TANK_PORT"
      return
    fi
    (
      cd "$root"
      nohup "$python_bin" -m uvicorn app.main:app --host 0.0.0.0 --port "$TANK_PORT" \
        >>"${root}/nobs-tank.out.log" 2>>"${root}/nobs-tank.err.log" &
    )
    return
  fi

  log "Could not start Tank automatically; start manually:"
  printf '    cd %q && python3 scripts/dev.py run\n' "$REPO_ROOT"
}

clear_device_token() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0
  log "Clearing NOBS_DEVICE_TOKEN in $env_file"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] clear NOBS_DEVICE_TOKEN in %s\n' "$env_file"
    return
  fi
  if grep -q '^NOBS_DEVICE_TOKEN=' "$env_file"; then
    sed -i '' 's/^NOBS_DEVICE_TOKEN=.*/NOBS_DEVICE_TOKEN=/' "$env_file"
  else
    printf '\nNOBS_DEVICE_TOKEN=\n' >>"$env_file"
  fi
}

reinit_agent_database() {
  local root="$1"
  local python_bin="$root/.venv/bin/python"
  if [[ ! -x "$python_bin" ]]; then
    python_bin="$REPO_ROOT/.venv/bin/python"
  fi
  if [[ ! -x "$python_bin" ]]; then
    python_bin="$(command -v python3)"
  fi

  log "Re-initializing empty agent database schema"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] %s -c "AgentStore(...)" in %s\n' "$python_bin" "$root"
    return
  fi

  (
    cd "$root"
    PYTHONPATH="${REPO_ROOT}:${PYTHONPATH:-}" "$python_bin" - <<'PY'
from pathlib import Path
from app.agent_store import AgentStore

db = Path("data/nobs-agent.db")
db.parent.mkdir(parents=True, exist_ok=True)
store = AgentStore(db)
store._connect().close()
print(f"initialized {db}")
PY
  )
}

wipe_client_state() {
  local root="$1"
  local rel path
  for rel in "${CLIENT_DATA_PATHS[@]}"; do
    path="$root/$rel"
    if [[ -e "$path" ]]; then
      log "Removing $rel"
      run rm -rf "$path"
    fi
  done
  for rel in "${CLIENT_DATA_DIRS[@]}"; do
    path="$root/$rel"
    log "Ensuring empty $rel/"
    run mkdir -p "$path"
  done
}

copy_client_state_to_backup() {
  local root="$1"
  local backup_dir="$2"
  local rel src dest dest_parent

  for rel in "${CLIENT_DATA_PATHS[@]}"; do
    src="$root/$rel"
    [[ -e "$src" ]] || continue
    dest="$backup_dir/$rel"
    dest_parent="$(dirname "$dest")"
    run mkdir -p "$dest_parent"
    run cp -a "$src" "$dest"
  done

  if [[ -f "$root/.env" ]]; then
    run cp -a "$root/.env" "$backup_dir/dotenv.backup"
  fi

  local api_env="$HOME/.config/nobs/nobs-api.env"
  if [[ -f "$api_env" ]]; then
    run mkdir -p "$backup_dir/host-config"
    run cp -a "$api_env" "$backup_dir/host-config/nobs-api.env"
  fi
}

backup_client_state() {
  local root="$1"
  local stamp backup_dir
  stamp="$(date +%Y%m%d-%H%M%S)"
  backup_dir="$root/data/backups/pre-reset-$stamp"

  log "Backing up client state to data/backups/pre-reset-$stamp/" >&2
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] mkdir %s and copy client db, workspaces, screenshots, nobs.db, .env\n' "$backup_dir" >&2
    printf '%s' "$backup_dir"
    return
  fi

  run mkdir -p "$backup_dir"
  copy_client_state_to_backup "$root" "$backup_dir"
  printf '%s' "$backup_dir"
}

verify_tank() {
  local base="http://127.0.0.1:$TANK_PORT"
  log "Health check: GET $base/health"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi

  local attempt
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsS -m 5 "$base/health" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  curl -fsS -m 5 "$base/health"
  echo

  log "Dashboard status: GET $base/dashboard/status"
  curl -fsS -m 10 "$base/dashboard/status" | head -c 400
  echo

  log "Dream-team policy requires a device token after pairing (POST /auth/apple or scripts/pairing.py)"
}

print_onboarding() {
  local root="$1"
  local backup_dir="${2:-}"
  cat <<EOF

Tank reset complete — first-time client checklist
=================================================

Backup: ${backup_dir:-"(dry-run — no backup created)"}

1. Generate a new pairing QR (creates NOBS_DEVICE_TOKEN in .env):
     cd ${root}
     python3 scripts/pairing.py

2. On iPhone: Privacy → Scan QR Code to Pair (or enter Tank URL + token).
   - Simulator Tank URL: http://127.0.0.1:${TANK_PORT}
   - Physical device: use your LAN IP (mDNS tank.local often fails)

3. Open the room-safe dashboard:
     http://127.0.0.1:${TANK_PORT}/dashboard

4. Open the dream-team workplace (after pairing):
     http://127.0.0.1:${TANK_PORT}/workplace

5. Verify authenticated routes once paired:
     curl -H "X-NOBS-Device-Token: <token>" http://127.0.0.1:${TANK_PORT}/ready
     curl -H "X-NOBS-Device-Token: <token>" http://127.0.0.1:${TANK_PORT}/dream-team/policy

6. On iPhone, clear old Tank pairing in Privacy if the app still shows a stale token.

Tank root: ${root}
Remote homelab reset: bash scripts/reset-tank-fresh.sh --remote
EOF
}

reset_local() {
  local root backup_dir
  root="$(detect_tank_root)"
  TANK_ROOT_DETECTED="$root"
  log "Tank root: $root"

  stop_local_tank
  backup_dir="$(backup_client_state "$root")"
  wipe_client_state "$root"
  clear_device_token "$root/.env"
  clear_device_token "$HOME/.config/nobs/nobs-api.env"
  reinit_agent_database "$root"
  start_local_tank
  verify_tank
  print_onboarding "$root" "$backup_dir"
}

reset_remote() {
  log "Resetting remote Tank on $TANK_HOST"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] ssh %s reset-remote-tank\n' "$TANK_HOST"
    return
  fi

  ssh -o ConnectTimeout=10 "$TANK_HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
ROOT="${TANK_ROOT:-$HOME/nobs}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$ROOT/data/backups/pre-reset-$STAMP"

CLIENT_DATA_PATHS=(
  "data/nobs-agent.db"
  "data/nobs-agent.db-shm"
  "data/nobs-agent.db-wal"
  "data/agent-workspace"
  "data/dream-team-sandbox"
  "data/dream-team/active"
  "data/workplace/screenshots"
  "nobs.db"
)

copy_client_state_to_backup() {
  local root="$1"
  local backup_dir="$2"
  local rel src dest dest_parent

  for rel in "${CLIENT_DATA_PATHS[@]}"; do
    src="$root/$rel"
    [[ -e "$src" ]] || continue
    dest="$backup_dir/$rel"
    dest_parent="$(dirname "$dest")"
    mkdir -p "$dest_parent"
    cp -a "$src" "$dest"
  done

  [[ -f "$root/.env" ]] && cp -a "$root/.env" "$backup_dir/dotenv.backup"
  if [[ -f "$HOME/.config/nobs/nobs-api.env" ]]; then
    mkdir -p "$backup_dir/host-config"
    cp -a "$HOME/.config/nobs/nobs-api.env" "$backup_dir/host-config/nobs-api.env"
  fi
}

systemctl --user stop nobs-api || true
mkdir -p "$BACKUP"
copy_client_state_to_backup "$ROOT" "$BACKUP"

rm -f "$ROOT/data/nobs-agent.db" "$ROOT/data/nobs-agent.db-shm" "$ROOT/data/nobs-agent.db-wal" "$ROOT/nobs.db"
rm -rf "$ROOT/data/agent-workspace" "$ROOT/data/dream-team-sandbox" "$ROOT/data/dream-team/active" "$ROOT/data/workplace/screenshots"
mkdir -p "$ROOT/data/agent-workspace" "$ROOT/data/dream-team-sandbox" "$ROOT/data/dream-team/active" "$ROOT/data/workplace/screenshots"

for env_file in "$ROOT/.env" "$HOME/.config/nobs/nobs-api.env"; do
  [[ -f "$env_file" ]] || continue
  if grep -q '^NOBS_DEVICE_TOKEN=' "$env_file"; then
    sed -i 's/^NOBS_DEVICE_TOKEN=.*/NOBS_DEVICE_TOKEN=/' "$env_file"
  else
    printf '\nNOBS_DEVICE_TOKEN=\n' >>"$env_file"
  fi
done

cd "$ROOT"
"$ROOT/.venv/bin/python" - <<'PY'
from pathlib import Path
from app.agent_store import AgentStore
db = Path("data/nobs-agent.db")
db.parent.mkdir(parents=True, exist_ok=True)
store = AgentStore(db)
store._connect().close()
PY

systemctl --user start nobs-api
sleep 3
curl -fsS -m 5 http://127.0.0.1:8000/health
echo
echo "Backup: $BACKUP"
REMOTE
}

if [[ "$REMOTE" -eq 1 ]]; then
  reset_remote
else
  reset_local
fi
