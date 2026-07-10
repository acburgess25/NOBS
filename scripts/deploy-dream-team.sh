#!/usr/bin/env bash
# Deploy Dream Team Sandbox to Tank (local-first; uses Tank Ollama only).
# Wraps the standard Tank deploy and verifies dream-team policy endpoint.
#
#   bash scripts/deploy-dream-team.sh
#
# Requires: SSH access to Tank, NOBS_DEVICE_TOKEN in Tank's .env
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TANK_HOST="${TANK_HOST:-tank}"

echo "==> Deploying NOBS backend (includes Dream Team Sandbox)"
bash "$REPO_ROOT/scripts/deploy-tank.sh"

echo "==> Verifying Dream Team policy endpoint (local-first metadata)"
TOKEN="$(ssh "$TANK_HOST" 'grep -E "^NOBS_DEVICE_TOKEN=" ~/nobs/.env 2>/dev/null | cut -d= -f2- | tr -d "\"'"'"'" || true')"
if [ -z "$TOKEN" ]; then
  echo "warn: NOBS_DEVICE_TOKEN not found in ~/nobs/.env; skip policy check"
  exit 0
fi

POLICY="$(ssh "$TANK_HOST" "curl -fsS -m 5 -H 'Authorization: Bearer $TOKEN' http://127.0.0.1:8000/dream-team/policy")"
echo "$POLICY" | grep -q '"would_use_cloud_quota":false' || {
  echo "error: dream-team policy missing local-first guarantee" >&2
  exit 1
}
echo "==> Dream Team Sandbox live on Tank (local Ollama only)"
