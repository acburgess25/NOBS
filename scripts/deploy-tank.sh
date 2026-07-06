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

echo "==> Restarting nobs-api"
ssh "$TANK_HOST" 'systemctl --user restart nobs-api && sleep 3 && systemctl --user is-active nobs-api'

echo "==> Health check"
ssh "$TANK_HOST" 'curl -fsS -m 5 http://127.0.0.1:8000/health'
echo
echo "==> Done"
