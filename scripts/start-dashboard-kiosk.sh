#!/usr/bin/env sh
set -eu

dashboard_url="${NOBS_DASHBOARD_URL:-http://127.0.0.1:8000/dashboard}"

echo "Waiting for dashboard at $dashboard_url..."
while ! curl -sS "http://127.0.0.1:8000/health" >/dev/null 2>&1; do
  sleep 1
done

if command -v firefox >/dev/null 2>&1; then
  exec firefox --kiosk --private-window "$dashboard_url"
fi

for browser in chromium chromium-browser google-chrome; do
  if command -v "$browser" >/dev/null 2>&1; then
    exec "$browser" \
      --kiosk \
      --incognito \
      --noerrdialogs \
      --disable-session-crashed-bubble \
      "$dashboard_url"
  fi
done

echo "No supported kiosk browser found. Install Firefox or Chromium." >&2
exit 1
