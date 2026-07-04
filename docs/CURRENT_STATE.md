# NOBS Current State

**Last updated:** July 3, 2026 (Developer Mode added)
**Purpose:** Tool-neutral handoff for any contributor entering without prior chat history.

This records implementation state, not product direction. [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) remains the approved product source of truth. Verify the branch, tests, and live services before treating deployment facts as current.

## Working now

### Apple app

- SwiftUI conversation-first prototype with onboarding and focused Chat, Today, Memory, Activity, Home, and Privacy surfaces.
- Local EventKit calendar permission flow and same-day event display.
- Configurable Tank address and Keychain-backed device token.
- Authenticated Tank chat with visible Local/Tank routing and privacy receipts.
- Honest local fallback when Tank is unavailable.
- Today can create a three-part Personal, Business, and Shared morning briefing
  from visible EventKit event titles and times, with a Tank privacy receipt.
- Activity lists pending Tank changes and provides explicit Approve and Deny actions.
- iOS 27 simulator build verified with Xcode 27 beta.

### Tank API and agent

- FastAPI service with public `/health` and device-token-protected `/ready`, `/chat`, and `/agent/*` routes.
- Local Ollama `qwen3:8b` chat and tool-calling path with bounded steps.
- Safe Developer Mode using `qwen2.5-coder:14b` with bounded read-only project listing, file reading, and searching (verified secure against traversal, symlink escapes, hidden files, and secrets).
- Explicit Personal, Business, and Shared contexts.
- Allowlisted tools only; no arbitrary shell or unrestricted filesystem access.
- Automatic read-only execution.
- SQLite-backed approval queue for state-changing tools.
- Atomic, non-replayable approval execution and local audit events.
- Current tools: Tank status, bounded workspace listing, approval-gated Markdown note creation, plus developer-mode project listing, project file reading, and project text search.
- Deterministic tests plus live Tank verification for read-only execution and denied changes.
- Device-authenticated daily briefing generation with validated contexts, a
  privacy receipt, and latest-per-date SQLite persistence.

### Website

- Vite/React build-in-public portfolio under `website/`.
- Approved Personal Workshop visual direction under `design/`.
- Content updated July 3 to describe the shipped agent core, dashboard, and security boundary; roadmap items carry shipped/in-progress status. Deployed live to nobsdash.com.

### Connected-screen dashboard

- Tank-hosted, room-safe dashboard at `/dashboard` with 15-second refresh.
- Light, Dark, and system-following Auto themes.
- API, Ollama, uptime, load, storage, agent activity, approval count, workspace counts, and GPU stats (utilization, VRAM, temperature via nvidia-smi with graceful fallback).
- Responsive 16:9 and narrow-screen layouts with connection-loss behavior.
- LIVE on Tank's HDMI display: GNOME minimal desktop + Firefox kiosk autostart, auto-login, survives reboot. GUI session is on tty2 (Ctrl+Alt+F2); text console on tty3.

### Tank host (live deployment facts, July 3 2026)

- Ubuntu 24.04, RTX 3060. Wi-Fi wlp5s0 = 192.168.0.59; ethernet enp6s0 also configured (`/etc/netplan/99-rescue.yaml`, renderer forced to networkd after a desktop-install outage).
- UFW: port 22 open; LAN (192.168.0.0/24) allowed to all ports.
- systemd user services (linger on): `nobs-api` (:8000), `nobsdash` (:4173), `cloudflared-nobsdash` (public tunnel), `open-webui` (:8080 local AI chat, `~/.openwebui` uv venv).
- Ollama models: `qwen3:8b` (app chat), `qwen2.5-coder:14b` (coding).
- No passwordless sudo; root changes need the console.

### Local-model coding pipeline

- Aider (`~/.local/bin/aider`, installed via uv, run with `--map-tokens 0` on macOS) drives `qwen2.5-coder:14b` on Tank through an SSH tunnel (`ssh -f -N -L 11434:127.0.0.1:11434 tank`).
- Proven loop on the GPU dashboard card (commit 38b14bf): supervisor writes spec → local model implements → tests run → failure report → model fixes. Use it for well-scoped backend tasks.

## Not working yet

- No persistent autonomous scheduler or recurring morning/evening jobs.
- No real calendar, reminders, email, messages, business-document, or web-research tool connected to Tank.
- No approved long-term memory workflow.
- No Sign in with Apple, household identity, subscription, or NOBScloud implementation.
- No arbitrary MCP server is trusted or installed by the NOBS agent.
- mDNS (`tank.local`) does not resolve from the LAN; clients use 192.168.0.59 directly.
- The briefing API is deployed and live-verified on Tank. The iOS UI is simulator-built;
  physical iPhone validation remains pending.

## Recommended next vertical slice

Add **persistent briefing schedules**:

1. Add persistent schedules without bypassing the tool-risk policy.
2. Let the user review, pause, and revoke each schedule from Activity.
3. Add a minimal Reminders input adapter with the same visible-data boundary.
4. Record schedule runs, sources, processing route, and approval outcomes.

Do not connect email, messages, health, location, purchases, deletion, or account administration until the approval UI and revocation path are usable.

## Verification

```bash
python3 scripts/dev.py check

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project NOBS.xcodeproj -scheme NOBS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  CODE_SIGNING_ALLOWED=NO build

cd website
pnpm build
```

## Handoff rule

When a capability moves between planned, implemented, tested, and live-verified, update this file in the same change. Repository tests prove code behavior; only a live check proves the current Tank deployment.
