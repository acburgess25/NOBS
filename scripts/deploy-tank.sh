#!/usr/bin/env bash
# Deploy the NOBS backend to the Ubuntu homelab Tank from this checkout.
#
# Production Tank runs on Ubuntu (systemd user service nobs-api at ~/nobs).
# Mac LaunchAgent is dev-only — use this script to update the real Tank.
#
# Usage (from repo root, on home LAN or Tailscale):
#   bash scripts/deploy-tank.sh              # auto-detect tank-lan / tank
#   bash scripts/deploy-tank.sh --remote     # same (explicit homelab deploy)
#   TANK_HOST=tank-lan bash scripts/deploy-tank.sh
#
# Syncs app/, dashboard/, workplace/, pyproject.toml; installs deps; restarts
# nobs-api; verifies /health, /workplace, and /dream-team/policy.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Deploy NOBS Tank code to the Ubuntu homelab host.

Options:
  --remote    Deploy to homelab Tank over SSH (default when host is reachable)
  --dry-run   Print planned actions without changing anything
  --help      Show this help

Environment:
  TANK_HOST   SSH host alias (default: auto — tank-lan, then tank)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote) REMOTE=1 ;;
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

resolve_tank_host() {
  if [[ -n "${TANK_HOST:-}" ]]; then
    printf '%s' "$TANK_HOST"
    return
  fi
  for candidate in tank-lan tank; do
    if ssh -o ConnectTimeout=4 -o BatchMode=yes "$candidate" 'echo ok' >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return
    fi
  done
  echo "error: cannot reach homelab Tank (tried tank-lan, tank). Set TANK_HOST." >&2
  exit 1
}

TANK_HOST="$(resolve_tank_host)"
REMOTE=1

log "Homelab Tank host: $TANK_HOST"

log "Checking Tank connectivity"
run ssh -o ConnectTimeout=8 -o BatchMode=yes "$TANK_HOST" 'echo "connected to $(hostname)"'

log "Syncing app/, dashboard/, workplace/, pyproject.toml to ~/nobs"
run rsync -az --delete "$REPO_ROOT/app/" "$TANK_HOST:~/nobs/app/"
run rsync -az --delete "$REPO_ROOT/dashboard/" "$TANK_HOST:~/nobs/dashboard/"
run rsync -az --delete "$REPO_ROOT/workplace/" "$TANK_HOST:~/nobs/workplace/"
run rsync -az "$REPO_ROOT/pyproject.toml" "$TANK_HOST:~/nobs/pyproject.toml"

log "Installing dependencies in Tank venv"
if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '[dry-run] ssh %s pip install -e .\n' "$TANK_HOST"
else
  ssh "$TANK_HOST" 'set -e
cd ~/nobs
if [ ! -x .venv/bin/python ]; then
  echo "error: ~/nobs/.venv/bin/python not found; create the venv on Tank first" >&2
  exit 1
fi
if [ -x .venv/bin/pip ]; then
  .venv/bin/pip install -q -e .
elif command -v uv >/dev/null 2>&1; then
  uv pip install -q --python .venv/bin/python -e .
elif [ -x "$HOME/.local/bin/uv" ]; then
  "$HOME/.local/bin/uv" pip install -q --python .venv/bin/python -e .
else
  echo "error: neither pip in the venv nor uv on PATH; cannot install dependencies" >&2
  exit 1
fi
echo "deps ok"'
fi

log "Restarting nobs-api"
if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '[dry-run] ssh %s systemctl --user restart nobs-api\n' "$TANK_HOST"
else
  ssh "$TANK_HOST" 'systemctl --user restart nobs-api && sleep 3 && systemctl --user is-active nobs-api'
fi

verify_endpoint() {
  local path="$1"
  local expect="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '[dry-run] verify GET %s expects %s\n' "$path" "$expect"
    return 0
  fi
  ssh "$TANK_HOST" "code=\$(curl -sS -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:8000${path} 2>/dev/null || echo 000); echo \"${path}: \${code}\"; test \"\${code}\" = \"${expect}\""
}

log "Health checks on Ubuntu Tank"
verify_endpoint "/health" "200"
verify_endpoint "/workplace" "307"
verify_endpoint "/dream-team/policy" "401"

if [[ "$DRY_RUN" -eq 0 ]]; then
  ssh "$TANK_HOST" 'curl -fsS -m 5 http://127.0.0.1:8000/health'
  echo
  ssh "$TANK_HOST" 'grep -q "Dream team workplace" ~/nobs/dashboard/index.html && echo "dashboard: feature cards present"'
fi

log "Deployed to Ubuntu Tank ($TANK_HOST). Open http://192.168.0.59:8000/dashboard (LAN) or Tailscale IP."
