#!/usr/bin/env bash
# Build the NOBS portfolio site and deploy to Tank (nobsdash.com origin).
# Run from the repo root while Tank is reachable over SSH.
#
#   bash scripts/deploy-nobsdash.sh
#
# Syncs website/dist/ to tank:~/services/nobsdash/current/ and restarts nobsdash.
set -euo pipefail

TANK_HOST="${TANK_HOST:-tank}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_DIR="~/services/nobsdash/current"

echo "==> Checking Tank connectivity"
ssh -o ConnectTimeout=8 -o BatchMode=yes "$TANK_HOST" 'echo "connected to $(hostname)"'

echo "==> Building website"
(
  cd "$REPO_ROOT/website"
  pnpm install --frozen-lockfile 2>/dev/null || pnpm install
  pnpm run build
)

echo "==> Syncing dist/ to ${TANK_HOST}:${REMOTE_DIR}"
rsync -az --delete "$REPO_ROOT/website/dist/" "$TANK_HOST:${REMOTE_DIR}/"

echo "==> Restarting nobsdash.service on Tank"
ssh "$TANK_HOST" 'systemctl --user restart nobsdash.service && sleep 1 && curl --fail --silent --show-error -o /dev/null -w "local / %{http_code}\n" http://127.0.0.1:4173/ && curl --fail --silent --show-error -o /dev/null -w "local /privacy.html %{http_code}\n" http://127.0.0.1:4173/privacy.html'

echo "==> Done. Public URLs:"
echo "    https://nobsdash.com/"
echo "    https://nobsdash.com/privacy.html"
