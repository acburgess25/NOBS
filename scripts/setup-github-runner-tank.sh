#!/usr/bin/env bash
# Install a GitHub Actions self-hosted runner on Tank (Linux).
# Usage (on Tank):
#   export GITHUB_RUNNER_TOKEN="<registration-token>"
#   bash scripts/setup-github-runner-tank.sh
#
# Get a token (on a machine with gh auth):
#   gh api repos/acburgess25/NOBS/actions/runners/registration-token -X POST -q .token

set -euo pipefail

REPO_URL="${GITHUB_REPO_URL:-https://github.com/acburgess25/NOBS}"
RUNNER_NAME="${GITHUB_RUNNER_NAME:-tank}"
RUNNER_LABELS="${GITHUB_RUNNER_LABELS:-self-hosted,linux,tank}"
RUNNER_DIR="${GITHUB_RUNNER_DIR:-$HOME/actions-runner}"

if [[ -z "${GITHUB_RUNNER_TOKEN:-}" ]]; then
  echo "Set GITHUB_RUNNER_TOKEN to a repo registration token." >&2
  echo "  gh api repos/acburgess25/NOBS/actions/runners/registration-token -X POST -q .token" >&2
  exit 1
fi

RUNNER_VERSION="${RUNNER_VERSION:-$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//')}"
ARCHIVE="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${ARCHIVE}"

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [[ ! -f ./config.sh ]]; then
  echo "Downloading runner v${RUNNER_VERSION}..."
  curl -fsSL -o "$ARCHIVE" "$DOWNLOAD_URL"
  tar xzf "$ARCHIVE"
  rm -f "$ARCHIVE"
fi

if [[ ! -f .runner ]]; then
  ./config.sh \
    --url "$REPO_URL" \
    --token "$GITHUB_RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --unattended \
    --replace
fi

./svc.sh install
./svc.sh start
./svc.sh status

echo "Tank runner online with labels: $RUNNER_LABELS"
