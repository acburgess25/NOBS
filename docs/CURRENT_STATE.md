# NOBS Current State

For full codebase reference see [`CODEBASE_REFERENCE.md`](CODEBASE_REFERENCE.md).

**Last updated:** July 28, 2026 (monetization / growth sequencing; next slice = payments + TestFlight)
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
- Authenticated Tank chat with visible Local/Tank/Apple Cloud routing and privacy receipts via `ModelRouter`.
- Policy-driven chat routing: Tank when home; conversational Tank-offline preferences (`stay local`, `use apple cloud`, `wait for tank`, `use nobscloud`); Apple Cloud (PCC) and NOBScloud paths behind feature flags.
- `AppleModelProvider` wraps Foundation Models on-device + `PrivateCloudComputeLanguageModel` (iOS 27+); honesty gate hides Apple Cloud badge until entitlement QA (`PCCFeatureFlags`).
- PCC quota UX in chat composer and Privacy (`PCCQuotaStatusView`); see `docs/PCC_INTEGRATION.md` and `docs/PCC_ENTITLEMENT_CHECKLIST.md`.
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
- A Live Activity (`NOBSWidgets/ApprovalLiveActivity.swift`) shows the latest pending Tank approval on the Lock Screen and Dynamic Island — concise tool name, reason, risk badge, and a "+N more waiting" count. Approve/Deny deep-link into the app (`nobs://approvals?id=…&action=…`) rather than executing from the extension, so every decision still goes through the same atomic, audited `AppModel.decideApproval` path. `ApprovalActivityManager` starts/updates/ends the activity from `AppModel.loadApprovals()`; it reattaches to a still-visible activity on relaunch and requires no new backend API.
- Activity shows Tank schedules and supports pause/revoke actions, plus sync action receipts with Local/Tank processing labels.
- Today briefing lists respect `UserProfile.accessibilityPreferences.responseLength`; refresh control and relative timestamp shown when a briefing exists.
- Onboarding collects response length (brief / standard / detailed) conversationally.
- Today shows a local evening wrap-up after 5pm from calendar, reminders, and briefing context.
- Shared `NOBSTheme` modifiers (`nobsScreenBackground`, `nobsSectionCard`, `NOBSEmptyState`, `NOBSBetaBadge`) and `Color+NOBS` tokens unify Chat, Today, onboarding, Privacy, Activity, and the briefing widget palette.
- Chat header shows a live Tank/Local connection status dot (online sage-green with a soft glow when Tank is connected, muted when working locally) while keeping the server/iPhone icon and "Tank"/"Local" text as non-color state indicators; VoiceOver announces the connection state.
- Design-system color alignment: caution split into warning ink (`#A8672E`) and a 12% callout wash, with the "notifications off" callout using amber-on-amber; new `nobsOnline` and `nobsWarningWash` tokens in `Color+NOBS`.
- App Store beta prep: metadata templates in `docs/app-store/`, checklist in `docs/APP_STORE_BETA_CHECKLIST.md`, privacy policy at `website/public/privacy.html`.
- Smart-home direction documented in `docs/GOOGLE_HOME_INTEGRATION.md` (Home Assistant bridge first; Google Home APIs later).

- iOS 27 simulator build verified with Xcode 27 beta (`scripts/build-ios-simulator.sh` or `CODE_SIGNING_ALLOWED=NO`).

### macOS mobile Tank (NOBSTank menu-bar app)

- New `NOBSTank` target in `NOBS.xcodeproj` (`NOBSTankMac/`): a macOS 27
  menu-bar app that turns the Mac into a portable Tank.
- Shows Tank API, Ollama, on-device model, and network status; restarts the
  `com.nobs.tank` LaunchAgent on demand.
- Quick-ask box routes Tank-first with honest fallback to the on-device
  Foundation Models `SystemLanguageModel` (macOS 27 beta framework); every
  answer is labeled Local or Tank.
- Displays the `nobs://pair` QR code (same payload as `scripts/pairing.py`)
  so the iPhone can pair with the Mac directly.
- `AskNOBSIntent` App Intent exposes "Ask NOBS Tank" to Siri, Spotlight, and
  Shortcuts on macOS 27.
- Reads the device token from `~/Documents/NOBS/.env` (path overridable via
  `nobs.tank.rootPath` user default).
- Security posture: Hardened Runtime enabled (`flags=0x10000(runtime)`
  verified on the signed build), which is the requirement for notarized
  direct distribution. App Sandbox is deliberately off: the app's purpose is
  supervising the user's own LaunchAgent (`launchctl`) and reading the local
  server's `.env`, both of which the sandbox forbids. Revisit only if App
  Store distribution is ever wanted.
- macOS Debug build and iOS simulator build both verified with Xcode 27 beta.

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
- Home control tools: `list_home_devices`, `control_home_device`, `control_secure_home_device`, `list_home_scenes`, `run_home_scene` — all backed by the existing Home Assistant bridge (`app/home_assistant.py`); state-changing calls always create a pending approval. No direct HomeKit protocol code on Tank (cross-platform requirement); Apple Home accessories reach Tank by being bridged into Home Assistant. iOS Home tab and Activity rendering for these proposals are still pending (see `docs/GOOGLE_HOME_INTEGRATION.md`).
- Overnight Tank queue: `overnight_tasks` SQLite table plus `POST/GET /overnight/tasks`, `GET /overnight/tasks/{id}`, `POST /overnight/tasks/{id}/cancel`. The scheduler claims and runs one queued task at a time through the normal agent/approval path when the current time falls inside the configured `NOBS_TIMEZONE` overnight window and Tank's recent CPU load is idle. See `docs/TANK_AGENT_CORE.md`.
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
- Physical iPhone validation and TestFlight upload remain pending (simulator build verified; archive requires home signing). See [`docs/CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md) for current CI failure modes.

## Recommended next vertical slice

**Get money paths open, put the app in strangers' hands, and make the work hire-able** (see [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md) and [`CAREER_AND_VISIBILITY.md`](CAREER_AND_VISIBILITY.md)):

1. Web: fill Stripe Payment Links in `website/public/support.json` and deploy; keep GitHub Sponsors CTA visible; add a Hire-me / contact CTA on the site.
2. App Store Connect: Paid Apps agreement, tax/banking, and IAP product IDs ([`APP_STORE_IAP_SETUP.md`](APP_STORE_IAP_SETUP.md)).
3. Fix distribution signing for app + widget; archive with `./scripts/stage-testflight-ipa.sh`.
4. Paste metadata from `docs/app-store/` into App Store Connect; host privacy at `https://nobsdash.com/privacy.html`.
5. External TestFlight: physical iPhone confirms chat, briefing, widget, optional Tank, and Support / tip flow.
6. Public visibility: finish [`PUBLIC_RELEASE.md`](PUBLIC_RELEASE.md), pin the repo, publish one case study (e.g. approval-gated agent), align LinkedIn with the shipped stack.

Do not market NOBScloud as delivered cloud capacity until backend entitlement sync ships. Do not connect email, messages, health, location, purchases automation, deletion, or account administration until the approval UI and revocation path are usable.

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
