#!/usr/bin/env sh
set -eu

# Wait a few seconds for the NOBS backend to start up
sleep 5

# Open Safari (or default browser) to the dashboard URL
open "http://127.0.0.1:8000/dashboard"
