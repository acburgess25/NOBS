# NOBS Current State

For full codebase reference see [`CODEBASE_REFERENCE.md`](CODEBASE_REFERENCE.md).

**Last updated:** August 14, 2026 (backend CI moved to GitHub-hosted Linux/macOS/Windows runners; Dream Team sandbox path guard fixed; PR backlog drained)
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
- Tank pairing now uses Bonjour discovery: Tank advertises `_nobs._tcp` without
  exposing a token, and the iPhone finds it before Sign in with Apple exchanges
  its device credential. Manual address and QR entry remain advanced recovery
  paths rather than the normal setup flow.
- Authenticated Tank chat with visible Local/Tank/Apple Cloud routing and privacy receipts via `ModelRouter`.
- Policy-driven chat routing: Tank when home; conversational Tank-offline preferences (`stay local`, `use apple cloud`, `wait for tank`, `use nobscloud`); Apple Cloud (PCC) and NOBScloud paths behind feature flags.
- **NOBScloud paid fallback (on-device entitlement):** StoreKit 2 tip jar + monthly subscription in Privacy → Account & support. An active subscription with `cloudOk` privacy comfort routes Tank-offline work through Apple Private Cloud Compute when PCC flags/entitlement/device allow it. Privacy receipts label this as Apple PCC under NOBScloud paid fallback—not a separate NOBS host. If PCC is unavailable, chat stays local with an honest explanation (no “coming soon” dead end). `StoreKitService` now checks `Transaction.currentEntitlements` at app launch (not only when the user opens Privacy → Support NOBS), so a subscriber's paid fallback is available from the start of a session. Backend entitlement sync is still not shipped.
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
- Hermetic backend test suite: `tests/conftest.py` runs every test from a fresh temporary working directory and scrubs `NOBS_*` environment variables, so the suite passes unchanged on a deployed Tank checkout with live `data/` state and a real `.env`.
- Device-authenticated daily briefing generation with validated contexts, a
  privacy receipt, and latest-per-date SQLite persistence.

### Website

- Vite/React build-in-public portfolio under `website/`.
- Approved Personal Workshop visual direction under `design/`.
- Content updated for TestFlight public beta; roadmap and hero copy match the iPhone app; privacy policy linked from footer. Deployed live to nobsdash.com (refresh after merge).

- Persistent background scheduler implemented, managing autonomous jobs, recurring schedules, and proactive idea generation.
- Basic API routes for synchronizing calendar and reminders (`/sync/calendar`, `/sync/reminders`) and managing briefing schedules (`/schedules`).

### Continuous integration

- **Backend CI runs on GitHub-hosted runners** (`.github/workflows/backend-ci.yml`): Python 3.12 on `ubuntu-latest`, `macos-latest`, and `windows-latest`, plus Python 3.11 on Linux to guard the `requires-python = ">=3.11"` floor. This is the cross-platform matrix `AI_WORKFLOW.md` requires; Windows had never actually been exercised before August 14, 2026.
- Historically every job targeted the self-hosted `tank` runner. That runner is no longer registered, so those jobs queued until they were cancelled and **no pull request could report green** regardless of code quality. Moving to hosted runners removed the dependency on a particular machine being awake. The repository is public, so hosted minutes are free.
- `NOBSTests on Mac runner` deliberately stays on the self-hosted Mac (`macbook`): it needs the Xcode 27 beta toolchain that hosted macOS images do not carry. It only runs when that Mac is online.
- **Xcode Cloud (`NOBS | Default`) currently fails on every pull request**, including documentation-only ones. It is configured in App Store Connect rather than in this repository, so its logs are not visible from the CLI. Treat it as a known-red external check until someone opens the build in App Store Connect; it is not evidence that a given PR is broken.
- Lint rules are pinned explicitly in `[tool.ruff.lint]`. Without that, the enforced rule set was whatever ruff shipped as default, which changed from roughly 20 rules to 413 in 0.16 and turned a routine version bump into 61 CI failures.

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
- No household identity or hosted NOBScloud servers (subscription delivers Apple PCC fallback on-device when available).
- No arbitrary MCP server is trusted or installed by the NOBS agent.
- mDNS (`tank.local`) may not resolve on every LAN; clients can use the Tank host IP directly (for example `http://192.168.1.100:8000`).
- **Physical iPhone validation is pending but not blocked.** It needs no upload, no App Store Connect, and no released toolchain — build and run on a device from Xcode 27 beta with a development profile. Only the simulator build has been verified so far. This is a prerequisite for a useful TestFlight build and can be done today.
- **TestFlight upload is blocked, and it is a toolchain problem rather than a CI one.** The Mac runner only has Xcode-beta 27.0 installed, and App Store Connect rejects beta-built uploads. The recommended fix is to wait for the Xcode 27 release candidate (expected early-to-mid September 2026), which App Store Connect accepts and which ships the full iOS 27 SDK with no code changes. A fallback using released Xcode 26.5 is documented but untested, and costs the Foundation Models path in that artifact. Both are written up under "Toolchain" in [`docs/CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md). Xcode 27 beta stays the primary development toolchain; no iOS 27 capability should be dropped to make distribution easier.
- **Apple signing is verified working as of August 14, 2026.** A `refresh_signing_only` dispatch completed green on the self-hosted Mac: it selected the distribution certificate whose private key is in the signing keychain, created both App Store provisioning profiles, and confirmed the widget profile carries `group.com.nobsdash.nobs`. Certificates, profiles, the App Group, and the App Store Connect credentials are **not** blockers. Only the archive/upload step is untested, and it is gated on the toolchain above rather than on anything Apple-account-related.
- **Xcode Cloud is redundant and permanently red.** iOS compilation and the full archive/upload pipeline both already run on the self-hosted Mac, so it adds no coverage; it should be retired in App Store Connect rather than debugged.
- **The autonomous idea generator fails in practice on the reference Mac Tank.** `trigger_autonomous_idea` runs a multi-step agent turn against Ollama under `NOBS_OLLAMA_TIMEOUT_SECONDS` (default 45), and the local Tank error log recorded 188 `AgentModelError`s caused by `httpx.ReadTimeout`. Ollama, the configured `qwen3:8b` model, and the Tank API were all verified healthy at the time, so this is timeout tuning for multi-step agent runs on that hardware rather than a code defect — but scheduled idea generation should be treated as not working until the timeout is raised and re-measured.
- The Dream Team sandbox was non-functional outside tests until August 14, 2026: the traversal guard in `_ensure_sandbox_dir` compared a resolved child path against an unresolved (relative by default) root, so it rejected every session id. Fixed, with regression coverage for the relative-root case that the previous tests missed by always passing an absolute `tmp_path`.
- Website one-time Square Payment Link is live in `website/public/support.json` (`donateOneTime`); a recurring `donateMonthly` link still needs to be created in the Square Dashboard and pasted in.
- GitHub Sponsors is **not** enabled — `github.com/sponsors/acburgess25` is a plain profile page with no Sponsor button (re-verified August 14, 2026). Both surfaces that could point at it are now closed: `support.json` leaves `githubSponsors` empty so the website hides that CTA, and `.github/FUNDING.yml` leaves the `github:` key commented out so GitHub does not render its own native "Sponsor" button on the repo page. These are separate mechanisms — the repo-page button comes straight from `FUNDING.yml` regardless of what the site shows. Re-enable both only after enrolling via GitHub → **Your sponsors** (`github.com/sponsors/accounts`) and confirming the profile page shows an actual Sponsor button.

## Recommended next vertical slice

**Get money into a stranger’s hands and verify the paid fallback on device** (see [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md)):

1. Web: create a recurring Square Payment Link and paste into `website/public/support.json` (`donateMonthly`); enroll in GitHub Sponsors via **Your sponsors** (`github.com/sponsors/accounts`), confirm the profile page shows a Sponsor button, then paste the URL back into `githubSponsors`.
2. App Store Connect: Paid Apps agreement, tax/banking, and IAP product IDs ([`APP_STORE_IAP_SETUP.md`](APP_STORE_IAP_SETUP.md)).
3. Fix distribution signing for app + widget; archive with `./scripts/stage-testflight-ipa.sh`.
4. After PCC entitlement QA, enable `NOBSPCC*` Info.plist flags so subscribed Tank-offline users get Apple Cloud fallback ([`PCC_ENTITLEMENT_CHECKLIST.md`](PCC_ENTITLEMENT_CHECKLIST.md)).
5. External TestFlight: physical iPhone confirms chat, briefing, widget, optional Tank, Support / tip / NOBScloud purchase + restore.
6. Later: backend entitlement sync before multi-device or hosted NOBScloud API claims.

Do not claim a separate NOBScloud server exists until it does. Do not connect email, messages, health, location, purchases automation, deletion, or account administration until the approval UI and revocation path are usable.

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
