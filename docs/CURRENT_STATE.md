# NOBS Current State

**Last updated:** July 7, 2026 (App Store beta polish + unified NOBS theme)
**Purpose:** Tool-neutral handoff for any contributor entering without prior chat history.

This records implementation state, not product direction. [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) remains the approved product source of truth. Verify the branch, tests, and live services before treating deployment facts as current.

## Working now

### Apple app

- SwiftUI conversation-first prototype with onboarding and focused Chat, Today, Memory, Activity, Home, and Privacy surfaces.
- Conversational onboarding collects name, mental-load sources, working hours, proactivity level, and one immediate problem before optional Sign in with Apple.
- `UserProfile` persisted locally (App Group `group.com.nobsdash.nobs` with Application Support fallback) drives personalized greetings and proactivity defaults.
- `BriefingSnapshot` written to shared storage after briefing generation for upcoming WidgetKit work.
- Home Screen and Lock Screen **Today's plan** widget reads `widget-snapshot.json` offline; respects response length and shows evening context after 5pm; tap opens `nobs://today`.
- Widget timelines reload when briefings update; cached briefing restores on app launch.
- Focus-aware briefings use system Focus status (`INFocusStatusCenter`) for concise toplines, business-first priorities, and suppressed proactive notifications.
- One clarifying-question local notification per day when proactivity is not Quiet; overlap actions open chat without silent calendar edits.
- Today highlights the clarifying question when notifications are denied; `ConflictResolutionSheet` supports overlap resolution.
- Siri and Shortcuts expose four App Intents: Prepare my day, Explain schedule, Ask NOBS, Show privacy receipt — with App Group cache fallback when the app is not running.
- `nobs://` deep links route to Today, Chat (with optional prompt), Privacy, and Tank pairing.
- Local EventKit calendar permission flow and same-day event display.
- EventKit calendar and reminders sync to Tank (`/sync/calendar`, `/sync/reminders`) using the same Keychain-backed device-token auth as chat.
- Configurable Tank address, KeychainAccess-backed device token storage, and
  shared app-root model ownership so onboarding, sign-in, and privacy flows
  stay in sync.
- Authenticated Tank chat with visible Local/Tank routing and privacy receipts.
- Honest local fallback when Tank is unavailable, without permanently marking
  Tank offline on non-connectivity API errors.
- Today now generates Morning Briefing v2 with structured topline, priorities,
  explicit conflict/overload risks, recommended sequencing, one clarifying
  question when ambiguity exists, and reversible suggested next actions.
- Briefing generation runs on-device first, then refines with Tank when
  connected, while keeping visible route badges and privacy receipts.
- Today can include local reminders (when permission is granted) alongside
  calendar events in briefing context.
- Activity lists pending Tank changes and provides explicit Approve and Deny actions.
- Activity shows Tank schedules and supports pause/revoke actions, plus sync action receipts with Local/Tank processing labels.
- Today briefing lists respect `UserProfile.accessibilityPreferences.responseLength`; refresh control and relative timestamp shown when a briefing exists.
- Onboarding collects response length (brief / standard / detailed) conversationally.
- Today shows a local evening wrap-up after 5pm from calendar, reminders, and briefing context.
- Shared `NOBSTheme` modifiers (`nobsScreenBackground`, `nobsSectionCard`, `NOBSEmptyState`, `NOBSBetaBadge`) and `Color+NOBS` tokens unify Chat, Today, onboarding, Privacy, Activity, and the briefing widget palette.
- App Store beta prep: metadata templates in `docs/app-store/`, checklist in `docs/APP_STORE_BETA_CHECKLIST.md`, privacy policy at `website/public/privacy.html`.

- iOS 27 simulator build verified with Xcode 27 beta (`scripts/build-ios-simulator.sh` or `CODE_SIGNING_ALLOWED=NO`).

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
- Content updated for TestFlight public beta; roadmap and hero copy match the iPhone app; privacy policy linked from footer. Deployed live to nobsdash.com (refresh after merge).

- Persistent background scheduler implemented, managing autonomous jobs, recurring schedules, and proactive idea generation.
- Basic API routes for synchronizing calendar and reminders (`/sync/calendar`, `/sync/reminders`) and managing briefing schedules (`/schedules`).

### Connected-screen dashboard

- Tank-hosted, room-safe dashboard at `/dashboard` with 15-second refresh.
- Light, Dark, and system-following Auto themes.
- API, Ollama, uptime, load, storage, agent activity, approval/proposal counts, workspace counts, and GPU stats.
- Responsive 16:9 and narrow-screen layouts with connection-loss behavior.
- LIVE on Tank's HDMI display: GNOME minimal desktop + Firefox kiosk autostart, auto-login, survives reboot. GUI session is on tty2 (Ctrl+Alt+F2); text console on tty3.

### Tank host (reference deployment)

- Ubuntu 24.04 homelab host with an NVIDIA GPU for local models.
- UFW allows SSH and LAN access; Tank API is intended for private-network use.
- systemd user services (with linger enabled): `nobs-api` (:8000), `nobsdash` (:4173), `cloudflared-nobsdash` (public tunnel), optional `open-webui` (:8080).
- Ollama models: `qwen3:8b` (app chat), `qwen2.5-coder:14b` (coding).
- No passwordless sudo; host administration stays at the console.
- Repository-standard local AI stack setup scripts are available for Tank and dev hosts (`scripts/setup-local-ai.sh`, `scripts/setup-local-ai.ps1`) plus tracked service templates under `deploy/tank/`.

### Local-model coding pipeline

- Aider (`~/.local/bin/aider`, installed via uv, run with `--map-tokens 0` on macOS) drives `qwen2.5-coder:14b` on Tank through an SSH tunnel (`ssh -f -N -L 11434:127.0.0.1:11434 tank`).
- Proven loop on the GPU dashboard card (commit 38b14bf): supervisor writes spec → local model implements → tests run → failure report → model fixes. Use it for well-scoped backend tasks.

## Not working yet

- No approved long-term memory workflow.
- No household identity, subscription, or NOBScloud implementation.
- No arbitrary MCP server is trusted or installed by the NOBS agent.
- mDNS (`tank.local`) may not resolve on every LAN; clients can use the Tank host IP directly (for example `http://192.168.1.100:8000`).
- Physical iPhone validation and TestFlight upload remain pending (simulator build verified; archive requires home signing).

## Recommended next vertical slice

**Physical iPhone validation, TestFlight upload, and App Store Connect submission:**

1. Fix distribution signing for app + widget; archive with `./scripts/stage-testflight-ipa.sh`.
2. Paste metadata from `docs/app-store/` into App Store Connect; host privacy at `https://nobsdash.com/privacy.html`.
3. Pair a physical iPhone and confirm chat, briefing, widget, and optional Tank sync end-to-end.

Do not connect email, messages, health, location, purchases, deletion, or account administration until the approval UI and revocation path are usable.

## Verification

```bash
python3 scripts/dev.py check

./scripts/build-ios-simulator.sh
# or:
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project NOBS.xcodeproj -scheme NOBS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  CODE_SIGNING_ALLOWED=NO build

cd website
pnpm build
```

## Handoff rule

When a capability moves between planned, implemented, tested, and live-verified, update this file in the same change. Repository tests prove code behavior; only a live check proves the current Tank deployment.
