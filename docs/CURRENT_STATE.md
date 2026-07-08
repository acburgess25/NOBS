# NOBS Current State

**Last updated:** July 8, 2026 (memory, evening briefing, Tank connectivity, research, and pairing improvements)
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
- **Day Rescue (partial):** When briefing detects overload or conflicts, Today shows a "Rescue this day" card with the primary risk explanation, realistic sequencing, honest no-silent-writes copy, and 1–3 tappable actions that open chat with a prefilled prompt or `ConflictResolutionSheet` for overlaps.
- Siri and Shortcuts expose four App Intents: Prepare my day, Explain schedule, Ask NOBS, Show privacy receipt — with App Group cache fallback when the app is not running.
- `nobs://` deep links route to Today, Chat (with optional prompt), Privacy, and Tank pairing.
- Local EventKit calendar permission flow and same-day event display.
- EventKit calendar and reminders sync to Tank (`/sync/calendar`, `/sync/reminders`) using the same Keychain-backed device-token auth as chat.
- Configurable Tank address, KeychainAccess-backed device token storage, and
  shared app-root model ownership so onboarding, sign-in, and privacy flows
  stay in sync.
- Authenticated Tank chat with visible Local/Tank routing and privacy receipts.
- Honest local fallback when Tank is unavailable (rule-based `localResponse`), without permanently marking Tank offline on non-connectivity API errors.
- Tank pairing via dashboard one-time codes: `nobs://pair?url=…&code=…` exchanges through `POST /auth/pair` (`TankClient.exchangePairingCode`).
- Default Tank address `http://tank.local:8000` on device; manual IP entry in Privacy when mDNS does not resolve.
- Today now generates Morning Briefing v2 with structured topline, priorities,
  explicit conflict/overload risks, recommended sequencing, one clarifying
  question when ambiguity exists, and reversible suggested next actions.
- Briefing generation runs on-device first, then refines with Tank when
  connected, while keeping visible route badges and privacy receipts.
- Today can include local reminders (when permission is granted) alongside
  calendar events in briefing context.
- Activity lists pending Tank changes and provides explicit Approve and Deny actions.
- Activity Approvals segment shows risk badges, expandable tool arguments, and a Proposals segment for agent ideas (automation, research, planning).
- Activity shows Tank schedules and supports pause/revoke actions, plus sync action receipts with Local/Tank processing labels.
- Today briefing lists respect `UserProfile.accessibilityPreferences.responseLength`; refresh control and relative timestamp shown when a briefing exists.
- Onboarding collects response length (brief / standard / detailed) conversationally.
- Today shows a local evening wrap-up after 5pm from calendar, reminders, and briefing context.
- Evening wrap-up card on Today (`generateEveningWrapUp`) summarizes completed events, open items, and a guilt-free close without requiring Tank.
- `ConflictResolutionSheet` supports overlap resolution; choosing an option prefills chat — full Day Rescue flow is specced in [`docs/DAY_RESCUE_SPEC.md`](DAY_RESCUE_SPEC.md) but not yet shipped.
- Shared `NOBSTheme` modifiers (`nobsScreenBackground`, `nobsSectionCard`, `NOBSEmptyState`, `NOBSBetaBadge`) and `Color+NOBS` tokens unify Chat, Today, onboarding, Privacy, Activity, and the briefing widget palette.
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
  answer is labeled Local or Tank. This is the primary Foundation Models routing spike; iPhone chat uses rule-based local fallback until an on-device FM path is added.
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
- `/ready` probes SQLite and Ollama dependency status; returns 503 with check details when not ready (`app/tank_health.py`).
- `POST /auth/pair` exchanges a dashboard one-time pairing code for the device token (codes expire; single use).
- Local Ollama `qwen3:8b` chat and tool-calling path with bounded steps.
- Safe Developer Mode using `qwen2.5-coder:14b` with bounded read-only project listing, file reading, and searching (verified secure against traversal, symlink escapes, hidden files, and secrets).
- Explicit Personal, Business, and Shared contexts.
- Allowlisted tools only; no arbitrary shell or unrestricted filesystem access.
- Automatic read-only execution.
- SQLite-backed approval queue for state-changing tools.
- Atomic, non-replayable approval execution and local audit events.
- Stale approval recovery on startup: long-running `executing` approvals reset to `pending` (`AgentStore.recover_stale_state`).
- Current tools: Tank status, weather (Open-Meteo), web fetch (public URLs only), Home Assistant read/list and approval-gated service calls, bounded workspace listing, approval-gated Markdown note creation, plus developer-mode project listing, project file reading, and project text search.
- Deterministic tests plus live Tank verification for read-only execution and denied changes.
- Device-authenticated daily briefing generation with validated contexts, heuristic merge (overload, conflicts, clarifying question), privacy receipt, and latest-per-date SQLite persistence.
- Evening briefing kind on `POST /briefing` with guilt-free wrap-up heuristics.
- Unified briefing builder in `app/briefing.py` shared by `POST /briefing` and the scheduler (same prompts, Ollama call, and heuristic merge).
- Memory v1 on Tank: `GET/PATCH/DELETE /memories`, chat remember/forget/correct/infer with privacy receipt fields; categories `preference`, `schedule`, `relationship`, `habit`, `priority`, `other`.
- Research pipeline: `POST/GET /research`, `GET /research/{job_id}` runs Tank agent jobs with stored summaries and sources.
- Home Assistant read-only device list: `GET /home/devices` (returns configured=false when HA is not set up).
- Scheduler uses IANA timezone (`settings.timezone`, `app/tank_time.py`) for local schedule matching.
- mDNS advertisement template for Tank (`deploy/nobs.avahi.service` registers `_nobs._tcp` and `tank.local` on the host).

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

- iOS Memory tab UI (Tank memory API and chat CRUD work; `ComingSoonView` on iPhone).
- iOS Home tab UI (Tank `GET /home/devices` read-only; Home tab still coming soon).
- iOS Bonjour browser for `_nobs._tcp` (host mDNS template exists; app uses `tank.local` default + manual IP).
- Outbound chat/briefing replay queue while Tank is offline (honest fallback exists; queue is TODO in `AppModel`).
- Day Rescue overload flow (partial: overlap sheet + briefing risks; full flow in [`docs/DAY_RESCUE_SPEC.md`](DAY_RESCUE_SPEC.md)).
- On-device Foundation Models routing on iPhone (macOS NOBSTankMac only today).
- No household identity, subscription, or NOBScloud implementation.
- No arbitrary MCP server is trusted or installed by the NOBS agent.
- mDNS (`tank.local`) may not resolve on every LAN; clients can use the Tank host IP directly (for example `http://192.168.1.100:8000`).
- Physical iPhone validation and TestFlight upload remain pending (simulator build verified; archive requires home signing). See [`docs/CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md) for current CI failure modes.

## Recommended next vertical slice

See [`docs/VERTICAL_SLICES.md`](VERTICAL_SLICES.md) for the next specced bet: **Day Rescue mode** (iOS + approvals).

**Immediate release path — physical iPhone validation, TestFlight upload, and App Store Connect submission:**

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
