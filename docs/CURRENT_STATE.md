# NOBS Current State

**Last updated:** July 3, 2026
**Purpose:** Tool-neutral handoff for any contributor entering without prior chat history.

This records implementation state, not product direction. [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) remains the approved product source of truth. Verify the branch, tests, and live services before treating deployment facts as current.

## Working now

### Apple app

- SwiftUI conversation-first prototype with onboarding and focused Chat, Today, Memory, Activity, Home, and Privacy surfaces.
- Local EventKit calendar permission flow and same-day event display.
- Configurable Tank address and Keychain-backed device token.
- Authenticated Tank chat with visible Local/Tank routing and privacy receipts.
- Honest local fallback when Tank is unavailable.
- iOS 27 simulator build verified with Xcode 27 beta.

### Tank API and agent

- FastAPI service with public `/health` and device-token-protected `/ready`, `/chat`, and `/agent/*` routes.
- Local Ollama `qwen3:8b` chat and tool-calling path with bounded steps.
- Explicit Personal, Business, and Shared contexts.
- Allowlisted tools only; no arbitrary shell or unrestricted filesystem access.
- Automatic read-only execution.
- SQLite-backed approval queue for state-changing tools.
- Atomic, non-replayable approval execution and local audit events.
- Current tools: Tank status, bounded workspace listing, and approval-gated Markdown note creation.
- Deterministic tests plus live Tank verification for read-only execution and denied changes.

### Website

- Vite/React build-in-public portfolio under `website/`.
- Approved Personal Workshop visual direction under `design/`.
- Website content has not yet been updated to describe the working Tank agent core.

### Connected-screen dashboard

- Tank-hosted, room-safe dashboard at `/dashboard` with 15-second refresh.
- Light, Dark, and system-following Auto themes.
- API, Ollama, uptime, load, storage, agent activity, approval count, and workspace counts.
- Responsive 16:9 and narrow-screen layouts with connection-loss behavior.
- Kiosk launcher and graphical-session autostart entry under `scripts/` and `deploy/tank/`.

## Not working yet

- No persistent autonomous scheduler or recurring morning/evening jobs.
- No iOS approval queue or Activity UI connected to `/agent/approvals`.
- No real calendar, reminders, email, messages, business-document, or web-research tool connected to Tank.
- No approved long-term memory workflow.
- No Sign in with Apple, household identity, subscription, or NOBScloud implementation.
- No arbitrary MCP server is trusted or installed by the NOBS agent.
- LAN access to Tank still requires confirming mDNS and a narrow firewall rule on the live server.
- Tank has no kiosk browser installed yet; automatic HDMI display launch requires an interactive sudo installation and graphical session.

## Recommended next vertical slice

Build a **scheduled daily briefing with visible approvals**:

1. Add persistent schedules without bypassing the tool-risk policy.
2. Add an iOS Activity/Approval client for listing, approving, and denying Tank proposals.
3. Define a minimal briefing-input contract from iPhone to Tank.
4. Start with user-selected calendar/reminder summaries and minimize raw sensitive data.
5. Produce separate Personal and Business sections plus an explicitly Shared summary.
6. Record sources, processing route, suggestions, and approval outcomes.

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
