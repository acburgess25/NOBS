# NOBS Current State

**Last updated:** July 8, 2026 (Tier 4.2 Home surface + Tier 4.3 research pipeline)
**Purpose:** Tool-neutral handoff for any contributor entering without prior chat history.

This records implementation state, not product direction. [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) remains the approved product source of truth. Verify the branch, tests, and live services before treating deployment facts as current.

## Working now

### Apple app

- SwiftUI conversation-first prototype with onboarding and focused Chat, Today, Memory, Activity, Home, and Privacy surfaces.
- Conversational onboarding collects name, mental-load sources, working hours, proactivity level, and one immediate problem before optional Sign in with Apple.
- `UserProfile` persisted locally (App Group `group.com.nobsdash.nobs` with Application Support fallback) drives personalized greetings and proactivity defaults.
- `BriefingSnapshot` written to shared storage after briefing generation for upcoming WidgetKit work.
- Home Screen and Lock Screen **Today's plan** widget (`NOBSWidgets` extension) reads `widget-snapshot.json` offline; tap opens `nobs://today`.
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
- Bonjour LAN discovery (`_nobs._tcp` via `NWBrowser`) with saved-URL fallback,
  manual IP entry, and one-tap reconnect in Privacy.
- Typed `TankAPIError` surfaces connection failures (timeout, DNS, HTTP 401)
  instead of silent false returns from `TankClient`.
- Offline chat message queue in App Group replays to Tank on reconnect with a
  visible privacy receipt ("Sent to Tank at …").
- Auto-refresh parallelizes Tank status, approvals, proposals, and schedules
  with `async let`.
- `AppModel` is a thin orchestrator (~560 lines); briefing, Tank sync/reachability,
  and approvals/schedules live in dedicated coordinators under `NOBS/Services/`.
- Authenticated Tank chat with visible Local/Tank routing and privacy receipts.
- **Foundation Models routing spike** (Tier 4.1): portable `NOBSModelRequest` contract;
  `LocalChatRouter` tries on-device Foundation Models when available, then falls back
  to deterministic local rules; route badge and privacy receipt show On-device AI vs
  Local rules with fallback reason; Privacy surfaces FM availability status.
- Honest local fallback when Tank is unavailable, without permanently marking
  Tank offline on non-connectivity API errors.
- Today now generates Morning Briefing v2 with structured topline, priorities,
  explicit conflict/overload risks, recommended sequencing, one clarifying
  question when ambiguity exists, and reversible suggested next actions.
- Briefing generation runs on-device first, then refines with Tank when
  connected, while keeping visible route badges and privacy receipts.
- **Evening wrap-up briefing** (Tier 3.1): on-device accomplishments,
  unfinished commitments (guilt-free tone), tomorrow prep; Tank refinement
  via `POST /briefing` with `kind: evening`; optional local notification;
  widget shows evening state or tomorrow preview after configured hour (default 17:00).
- Today can include local reminders (when permission is granted) alongside
  calendar events in briefing context.
- Activity lists pending Tank changes and provides explicit Approve and Deny actions.
- Activity shows Tank schedules and supports pause/revoke actions, plus sync action receipts with Local/Tank processing labels.
- **Memory v1:** Tank SQLite store with `GET`/`PATCH`/`DELETE /memories`; chat hooks for remember/forget/correct; inferred facts from conversation; Memory tab lists source, date, and category with delete/correct controls; privacy receipts list memory categories used in responses.
- **Home surface (Tier 4.2):** `GET /home/devices` returns read-only Home Assistant entities from Tank; Home tab groups devices by domain with honest platform copy (Apple Home via HA connected when configured; Google Home and Alexa not connected yet); device control stays approval-gated via chat.
- **Research brief pipeline (Tier 4.3):** `POST /research` runs Tank agent with `web_search`, `read_url`, and `read_news_feeds`; jobs persisted in SQLite with cited sources; NOBScloud entitlement gate in production (`nobscloud_entitled` KV); Activity tab lists research jobs with source links and a start-research form.
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
  privacy receipt, `kind: morning | evening` support, and latest-per-date SQLite persistence.
- `GET /home/devices` for read-only Home Assistant device listing.
- `GET`/`POST /research` for sourced research briefs with NOBScloud entitlement gating in production.

### Website

- Vite/React build-in-public portfolio under `website/`.
- Approved Personal Workshop visual direction under `design/`.
- Content updated July 3 to describe the shipped agent core, dashboard, and security boundary; roadmap items carry shipped/in-progress status. Deployed live to nobsdash.com.

- Persistent background scheduler implemented, managing autonomous jobs, recurring schedules, and proactive idea generation.
- Basic API routes for synchronizing calendar and reminders (`/sync/calendar`, `/sync/reminders`), managing briefing schedules (`/schedules`), and managing approved memories (`/memories`).

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

- No CloudKit or cross-device memory sync (Tank is the v1 store of record).
- No household identity, subscription, or NOBScloud implementation.
- No arbitrary MCP server is trusted or installed by the NOBS agent.
- mDNS (`tank.local`) may not resolve on every LAN; Bonjour browse and manual IP entry in Privacy are the supported fallback paths.
- Physical iPhone end-to-end validation not yet recorded on hardware (framework and checklist are ready; see below).

## Physical device validation framework

Structured QA for real iPhone testing is documented and ready to run. **Executing the checklist still requires contributor hardware** — CI and simulators cannot substitute for Keychain persistence, QR pairing, widgets on a Home Screen, Siri, or notification delivery.

| Document | Purpose |
|---|---|
| [`DEVICE_HUB_QA.md`](DEVICE_HUB_QA.md) | Simulator build matrix + physical device checklist summary + automation boundaries |
| [`PHYSICAL_DEVICE_QA.md`](PHYSICAL_DEVICE_QA.md) | Step-by-step pass/fail template for a validation session |

**What can be automated today**

- Backend: `python3 scripts/dev.py check` (pytest suite, including `/memories`, `/schedules`, `/home/devices`, `/research`, and `app/scheduler.py`)
- iOS: `xcodebuild test` with `NOBSTests` on simulator (16 unit tests; Tank decode, briefing snapshot, local rules routing)
- Pairing URL contract: dashboard `/dashboard/status` pairing object and `scripts/pairing.py` output format

**What requires manual physical device runs**

- QR pairing via Tank dashboard or `scripts/pairing.py`
- Keychain-backed device token survival across force-quit and reboot
- Authenticated chat, briefing Tank refinement, approve/deny on Activity
- EventKit calendar/reminders sync to Tank (`/sync/calendar`, `/sync/reminders`)
- WidgetKit timeline from `widget-snapshot.json` on Home Screen / Lock Screen
- App restart reconnect on the home LAN without re-pairing
- Siri intents and local notifications (optional section in template)

**Status:** Framework **shipped**; first signed-device pass/fail session **pending** until a contributor completes [`PHYSICAL_DEVICE_QA.md`](PHYSICAL_DEVICE_QA.md) and records results in the session block.

## Recommended next vertical slice

**Run physical iPhone validation:**

1. Complete [`PHYSICAL_DEVICE_QA.md`](PHYSICAL_DEVICE_QA.md) on a signed physical iPhone (dashboard QR or `scripts/pairing.py` pairing).
2. Verify Bonjour discovery, one-tap reconnect, and offline message replay on the home LAN.
3. Update this file with pass/fail and device metadata when the session completes.

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
