#!/usr/bin/env bash
# Set up private remote access to the Tank using Tailscale.
#
# Run this ON THE TANK, while you are at home. It is safe to re-run.
#
#   bash scripts/setup-tank-remote-access.sh
#
# What it does:
#   1. Installs Tailscale if it is missing.
#   2. Brings this machine onto your tailnet (opens a browser link to log in).
#   3. Checks the Tank API answers on the tailnet address.
#   4. Refuses to continue if Tailscale Serve or Funnel is publishing the API.
#
# Why Tailscale and not a tunnel on your domain:
#   The Tank decides "is this request physically at the Tank?" from the
#   connection's peer address (app/pairing.py, is_loopback_client). That is what
#   gates /dashboard/pairing, the route that hands out the device token.
#
#   A VPN keeps that address honest: your phone shows up as 100.x.x.x, which is
#   correctly treated as remote, so the device token is still required.
#
#   A reverse proxy or tunnel launders it: cloudflared, nginx, `tailscale serve`
#   and `tailscale funnel` all connect to the API from localhost, so every
#   request on earth would look like it came from the Tank itself and anyone who
#   found the address could read the device token. Never put one in front of
#   port 8000. See docs/REMOTE_ACCESS.md.

set -euo pipefail

API_PORT="${NOBS_API_PORT:-8000}"

info() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*" >&2; }
die()  { printf '\n\033[1mStopped:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- 1. install

info "1/4  Tailscale"

if command -v tailscale >/dev/null 2>&1; then
  ok "already installed ($(tailscale version | head -1))"
else
  case "$(uname -s)" in
    Linux)
      echo "  Installing via the official script (needs sudo)..."
      curl -fsSL https://tailscale.com/install.sh | sh
      ok "installed"
      ;;
    Darwin)
      die "On macOS, install Tailscale from the App Store or 'brew install --cask tailscale',
       open it once, then re-run this script."
      ;;
    *)
      die "Unsupported OS: $(uname -s). Install Tailscale manually, then re-run."
      ;;
  esac
fi

# ------------------------------------------------------------------- 2. join

info "2/4  Joining your tailnet"

if tailscale status >/dev/null 2>&1; then
  ok "already logged in"
else
  echo "  A login URL will be printed below. Open it and approve this machine."
  echo
  # --ssh is deliberately not enabled: this script is for reaching the API, not
  # for opening a new way into the box.
  sudo tailscale up --hostname=tank --accept-routes=false
  ok "joined"
fi

TAILNET_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
[ -n "$TAILNET_IP" ] || die "Tailscale is running but has no IPv4 address yet. Re-run in a moment."
ok "this machine is $TAILNET_IP"

# Parse this machine's own name. A grep over the JSON can match a peer's
# DNSName instead, which would print someone else's address as if it were the
# Tank's, so read Self explicitly.
TAILNET_NAME="$(tailscale status --json 2>/dev/null | python3 -c '
import json, sys
try:
    print((json.load(sys.stdin).get("Self") or {}).get("DNSName", "").rstrip("."))
except Exception:
    pass
' 2>/dev/null || true)"

# --------------------------------------------------------- 3. no public proxy

info "3/4  Checking nothing is publishing the API"

if ! tailscale serve status >/dev/null 2>&1; then
  # Older Tailscale, or the subcommand is unavailable. Say so rather than
  # reporting a clean result we did not actually verify.
  warn "Could not run 'tailscale serve status', so this was not verified."
  warn "Check by hand that nothing forwards to port ${API_PORT}:"
  warn "  tailscale serve status"
  SERVE_STATUS=""
  SERVE_CHECKED=0
else
  SERVE_STATUS="$(tailscale serve status 2>/dev/null || true)"
  SERVE_CHECKED=1
fi

if [ "$SERVE_CHECKED" -eq 1 ] && printf '%s' "$SERVE_STATUS" | grep -q ":${API_PORT}"; then
  warn "Tailscale Serve or Funnel is forwarding to port ${API_PORT}."
  warn "That makes every remote request look local to the Tank, which would let"
  warn "anyone who reaches it read your device token."
  warn "Turn it off with:  sudo tailscale funnel --https=443 off"
  warn "               and sudo tailscale serve --https=443 off"
  die "Refusing to finish while the API is being proxied."
fi
if [ "$SERVE_CHECKED" -eq 1 ]; then
  ok "no proxy in front of port ${API_PORT}"
fi

# ------------------------------------------------------------------ 4. verify

info "4/4  Checking the Tank API answers"

if curl -fsS --max-time 5 "http://127.0.0.1:${API_PORT}/health" >/dev/null 2>&1; then
  ok "API is up locally"
else
  warn "No response on http://127.0.0.1:${API_PORT}/health"
  warn "Start it with:  systemctl --user start nobs-api"
  die "Bring the API up, then re-run."
fi

if curl -fsS --max-time 5 "http://${TAILNET_IP}:${API_PORT}/health" >/dev/null 2>&1; then
  ok "API answers on the tailnet address"
else
  warn "API did not answer on ${TAILNET_IP}:${API_PORT}."
  warn "It must bind 0.0.0.0, not 127.0.0.1 (deploy/tank/nobs-api.service does)."
  die "Fix the bind address, then re-run."
fi

# -------------------------------------------------------------------- finish

cat <<EOF

$(printf '\033[1mRemote access is ready.\033[0m')

  Tank address:  http://${TAILNET_IP}:${API_PORT}${TAILNET_NAME:+
  Or by name:    http://${TAILNET_NAME}:${API_PORT}}

Do these two things now, before you leave:

  1. Install Tailscale on your phone and sign in with the same account.
     Your phone will not reach the Tank until it is on the tailnet too.

  2. Pair your phone HERE, at the Tank.
     Pairing is refused from anywhere that is not the Tank itself -- that is
     deliberate, and it applies over the tailnet as well. Open the dashboard on
     the Tank display and pair now, or you will not be able to from the road.

No ports are open on your router, and nothing is published on a public domain.

EOF
