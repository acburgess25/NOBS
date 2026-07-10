#!/usr/bin/env bash
# Create App Store provisioning profiles for NOBS targets via App Store Connect API.
set -euo pipefail

python3 scripts/ci-create-app-store-profiles.py
