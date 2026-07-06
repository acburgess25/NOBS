#!/usr/bin/env bash
# Deploy the NOBS backend to Tank from this checkout.
# Run from the repo root while on the home network (Tank must be reachable over SSH).
#
#   bash scripts/deploy-tank.sh
#
# Syncs app/, dashboard/, and pyproject.toml to tank:~/nobs, installs
# dependencies into Tank's venv, restarts nobs-api, and verifies /health.
set -euo pipefail

TANK_HOST="${TANK_HOST:-tank}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Checking Tank connectivity"
ssh -o ConnectTimeout=8 -o BatchMode=yes "$TANK_HOST" 'echo "connected to $(hostname)"'

echo "==> Syncing app/, dashboard/, pyproject.toml"
rsync -az --delete "$REPO_ROOT/app/" "$TANK_HOST:~/nobs/app/"
rsync -az --delete "$REPO_ROOT/dashboard/" "$TANK_HOST:~/nobs/dashboard/"
rsync -az "$REPO_ROOT/pyproject.toml" "$TANK_HOST:~/nobs/pyproject.toml"

echo "==> Installing dependencies in Tank venv"
ssh "$TANK_HOST" 'cd ~/nobs && if [ -x .venv/bin/pip ]; then .venv/bin/pip install -q -e .; else ~/.local/bin/uv pip install -q --python .venv/bin/python -e .; fi && echo "deps ok"'

echo "==> Restarting nobs-api"
ssh "$TANK_HOST" 'systemctl --user restart nobs-api && sleep 3 && systemctl --user is-active nobs-api'

echo "==> Health check"
ssh "$TANK_HOST" 'curl -s -m 5 http://127.0.0.1:8000/health'
echo
echo "==> Done"
