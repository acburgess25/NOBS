# NOBS Codebase Reference

**Last updated:** July 10, 2026  
**Repository:** [acburgess25/NOBS](https://github.com/acburgess25/NOBS)  
**Purpose:** Canonical onboarding and reference for humans, agents, and contributors. When this document disagrees with a chat transcript, trust the repo on `main` and the documents linked here.

---

## Product summary

NOBS is a **local-first, privacy-first personal assistant** for the Apple ecosystem. It reduces mental load by turning a chaotic day into a realistic plan — morning briefing, chat, approvals, and optional Tank-backed compute — while keeping everyday intelligence on the user's iPhone or private Tank hardware. Optional NOBScloud is a future capability, not a requirement.

**Tagline:** "Your technology. Finally working for you."

**Product source of truth:** [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md)  
**Implementation boundary:** [`CURRENT_STATE.md`](CURRENT_STATE.md)  
**Agent workflow rules:** [`AI_WORKFLOW.md`](AI_WORKFLOW.md)

---

## Repository map

```
NOBS/
├── NOBS/                    # SwiftUI iPhone/iPad app (chat-first shell)
├── NOBSWidgets/             # WidgetKit + Live Activity extension
├── NOBSTankMac/             # macOS 27 menu-bar portable Tank supervisor
├── NOBSTests/               # iOS unit tests (ModelRouter, routing fixtures)
├── NOBS.xcodeproj/          # Xcode project (4 targets: NOBS, NOBSWidgets, NOBSTank, NOBSTests)
├── app/                     # FastAPI Tank API, agent core, dashboard, scheduler
├── tests/                   # Backend pytest suite (103 tests)
├── scripts/                 # Dev, CI, signing, deploy, pairing, local AI setup
├── deploy/tank/             # systemd units, kiosk desktop, cloudflared templates
├── docs/                    # Product, architecture, ops, App Store prep
├── design/                  # Approved visual references and brand assets
├── website/                 # Vite/React public site (nobsdash.com)
├── dashboard/               # Static assets for Tank connected-screen dashboard
├── workplace/               # Live animated dream-team workplace UI
├── ExportOptions.plist      # App Store Connect export (automatic signing)
├── pyproject.toml           # Python package (nobs-tank-api 0.1.0)
├── .env.example             # Backend env template (never commit .env)
├── AGENTS.md / CLAUDE.md    # Tool adapters → point to docs/AI_WORKFLOW.md
└── README.md                # Quick start
```

| Area | Owns |
|------|------|
| `NOBS/` | iOS app UI, `AppModel` state, Tank client, routing, onboarding, Today, Activity, Privacy |
| `NOBSWidgets/` | Today's plan widget, approval Live Activity |
| `NOBSTankMac/` | macOS menu-bar Tank supervisor, QR pairing, local quick-ask |
| `app/` | FastAPI routes, Ollama bridge, agent tools/approvals, Home Assistant bridge, scheduler |
| `tests/` | Deterministic API, agent, briefing, sync, overnight queue, home scene tests |
| `scripts/` | Cross-platform dev entrypoints, CI signing, TestFlight staging, Tank deploy |
| `deploy/tank/` | Reference homelab deployment (systemd, kiosk, tunnel) |
| `website/` | Public marketing site, privacy policy HTML |
| `docs/` | Durable product and engineering truth |

Maintainer-only notes live in the private repo [NOBS-private](https://github.com/acburgess25/NOBS-private); see `docs/internal/README.md`.

---

## Tech stack and versions

| Component | Version / value |
|-----------|-----------------|
| **iOS marketing version** | `4.0` (build `1`) |
| **NOBSTank macOS version** | `0.1.0` |
| **Backend package** | `nobs-tank-api` `0.1.0` |
| **Swift** | 6.0 |
| **iOS deployment target** | 18.0 (built/tested on iOS 27 simulator) |
| **macOS deployment target** | 27.0 (NOBSTank) |
| **Python (required)** | ≥ 3.11 |
| **Python (CI Tank runner)** | 3.12 |
| **Python (CI Mac runner)** | 3.13 |
| **Xcode** | 27 beta — `/Applications/Xcode-beta.app` |
| **Simulator default** | iPhone 17 Pro, iOS 27.0 |
| **Apple Developer Team ID** | `K853LKQLAS` |
| **App Store Connect app ID** | `6772071553` |
| **License** | AGPL-3.0-or-later |

### Bundle identifiers

| Target | Bundle ID |
|--------|-----------|
| NOBS (iOS app) | `com.nobsdash.nobs` |
| NOBSWidgets | `com.nobsdash.nobs.widgets` |
| NOBSTests | `com.nobsdash.nobs.tests` |
| NOBSTank (macOS) | `com.nobsdash.nobstank` |

### Entitlements and capabilities

| Capability | Where |
|------------|-------|
| App Group `group.com.nobsdash.nobs` | App + widget (shared `widget-snapshot.json`, profile cache) |
| Sign in with Apple | App only |
| Live Activities | App (`NSSupportsLiveActivities` in Info.plist) |
| URL scheme `nobs://` | Deep links to Today, Chat, Privacy, approvals, pairing |

### Ollama models (Tank default)

| Model | Role |
|-------|------|
| `qwen3:8b` | App chat (`NOBS_OLLAMA_MODEL`) |
| `qwen2.5-coder:14b` | Developer mode / coding agent (`NOBS_CODING_MODEL`) |

---

## Architecture overview

### System diagram

```
┌─────────────────┐     device token      ┌──────────────────────────────┐
│  iPhone (NOBS)  │◄────HTTP/LAN─────────►│  Tank (FastAPI :8000)        │
│  SwiftUI app    │     /chat, /agent/*   │  Ollama, agent, approvals    │
│  Local FM / PCC │     /sync/*, /briefing│  SQLite, scheduler, HA bridge│
└────────┬────────┘                       └──────────────┬───────────────┘
         │ App Group                                      │ HDMI kiosk
         ▼                                                ▼
┌─────────────────┐                       ┌──────────────────────────────┐
│ NOBSWidgets     │                       │ /dashboard (room-safe UI)    │
│ widget + Live   │                       │ nobsdash.com (public site)   │
│ Activity        │                       └──────────────────────────────┘
└─────────────────┘

Optional: NOBSTankMac menu-bar app supervises LaunchAgent + shows pair QR
```

### iOS layers

| Layer | Responsibility | Key files |
|-------|----------------|-----------|
| **App shell** | `NOBSApp` → `ConversationView`, deep links, notifications | `NOBS/NOBSApp.swift`, `ConversationView.swift` |
| **State** | Single `AppModel` owns chat, Today, approvals, Tank config | `NOBS/AppModel.swift` |
| **Services** | Tank HTTP, calendar, routing, profile, App Group I/O | `NOBS/Services/*` |
| **Routing** | Policy-driven Local / Tank / Apple Cloud / NOBScloud | `ModelRouter.swift`, `AppleModelProvider.swift`, `PCCFeatureFlags.swift` |
| **Views** | Today, Activity, Privacy, onboarding, theme | `NOBS/Views/*` |
| **Intents** | Siri / Shortcuts (4 intents) | `NOBS/Intents/NOBSAppIntents.swift` |
| **Widget** | Offline briefing snapshot | `NOBSWidgets/BriefingWidget.swift`, `BriefingSnapshotWriter.swift` |

Chat is the home surface. Contextual views (Today, Memory, Home, Activity, Privacy) are reached from conversation, not a permanent tab bar.

### Backend modules

| Module | Responsibility |
|--------|----------------|
| `app/main.py` | FastAPI app, routes, auth dependency, lifespan |
| `app/config.py` | `NOBS_*` settings from `.env` |
| `app/agent.py` | Tank agent loop, tool dispatch |
| `app/agent_tools.py` | Allowlisted tool registry (read-only vs approval-gated) |
| `app/agent_store.py` | SQLite approvals, proposals, audit |
| `app/scheduler.py` | Recurring schedules, overnight queue, proactive jobs |
| `app/dashboard.py` | Connected-screen status JSON |
| `app/home_assistant.py` | Home Assistant REST bridge for smart-home tools |

### Data flow: Tank ↔ iPhone

1. **Pairing:** User sets Tank URL + device token in Privacy (or scans `nobs://pair` QR from `scripts/pairing.py` / NOBSTankMac). Token stored in Keychain via `TankConfiguration`.
2. **Auth:** Requests send `X-NOBS-Device-Token` header. Tank rejects missing/invalid tokens on protected routes.
3. **Chat:** `TankClient` → `POST /chat`. `ModelRouter` prefers Tank when reachable; shows route badge and privacy receipt.
4. **Briefing:** On-device generation first; optional `POST /briefing` refinement when Tank is connected.
5. **Sync:** `POST /sync/calendar` and `/sync/reminders` after EventKit permission.
6. **Approvals:** `GET /agent/approvals` → Activity UI + Live Activity; `POST /agent/approvals/{id}` with approve/deny (atomic, audited).
7. **Widget:** `BriefingSnapshotWriter` writes `widget-snapshot.json` to App Group; widget reads offline.

Default Tank URLs: Simulator `http://127.0.0.1:8000`; physical device `http://tank.local:8000` (mDNS may fail — use LAN IP).

---

## Key files index

| Path | What it does | Touch when |
|------|--------------|------------|
| `NOBS/AppModel.swift` | Central app state, briefing, approvals, Tank I/O | Any feature changing app behavior |
| `NOBS/Services/ModelRouter.swift` | Chat/briefing route selection (Local/Tank/PCC) | Routing policy or offline behavior |
| `NOBS/Services/TankClient.swift` | HTTP client for Tank API | New API endpoints or auth |
| `NOBS/Services/TankConfiguration.swift` | Keychain-backed URL + token | Pairing or storage changes |
| `NOBS/ConversationView.swift` | Chat shell and navigation | Primary UX flow |
| `NOBS/Views/TodayView.swift` | Morning briefing v2 UI | Briefing presentation |
| `NOBS/Views/ActivityView.swift` | Approvals, schedules, sync receipts | Agent approval UX |
| `NOBS/Services/AppleModelProvider.swift` | Foundation Models + PCC wrapper | Apple Cloud integration |
| `NOBS/Services/PCCFeatureFlags.swift` | Gates PCC badge until entitlement QA | PCC rollout |
| `NOBSWidgets/BriefingWidget.swift` | Home/Lock Screen widget | Widget layout or data |
| `NOBSWidgets/ApprovalLiveActivity.swift` | Lock Screen approval UI | Live Activity behavior |
| `app/main.py` | All HTTP routes | New API surface |
| `app/agent_tools.py` | Tool definitions and risk class | New agent capabilities |
| `app/agent_store.py` | Approval persistence | Approval lifecycle |
| `app/config.py` | Env-backed settings | New configuration keys |
| `scripts/dev.py` | Backend setup/test/lint/run | Dev workflow |
| `scripts/reset-tank-fresh.sh` | Wipe Tank client state + re-pair | Fresh install / QA reset |
| `scripts/build-ios-simulator.sh` | Unsigned simulator build | iOS compile check |
| `scripts/test-ios.sh` | NOBSTests on simulator | Swift routing tests |
| `scripts/stage-testflight-ipa.sh` | Local archive → `~/nobs-build/NOBS.ipa` | Home TestFlight prep |
| `.github/workflows/testflight.yml` | CI archive + TestFlight upload | Signing automation |
| `.github/workflows/backend-ci.yml` | Python + NOBSTests CI | CI matrix changes |
| `ExportOptions.plist` | App Store export signing style | Distribution signing |
| `docs/PRODUCT_DECISIONS.md` | Approved product direction | Only when decision owner supersedes |
| `docs/CURRENT_STATE.md` | What works vs planned | After capability changes |

---

## Local development

### Prerequisites

- **Backend:** Python 3.11+ (3.12+ recommended)
- **iOS:** macOS with Xcode 27 beta, iOS 27 simulator runtime
- **Tank (optional):** Ollama with `qwen3:8b` pulled
- **Website (optional):** Node/pnpm for `website/`

### Backend

```bash
cd /path/to/NOBS
./scripts/setup.sh          # or scripts/setup.ps1 on Windows
python3 scripts/dev.py setup
cp .env.example .env        # set NOBS_DEVICE_TOKEN to a strong secret
python3 scripts/dev.py run  # uvicorn on :8000
```

Useful commands:

```bash
python3 scripts/dev.py check   # pytest + ruff (103 tests)
python3 scripts/dev.py test
python3 scripts/dev.py lint
```

### iOS (simulator — no signing required)

```bash
open NOBS.xcodeproj
# Scheme: NOBS → iPhone 17 Pro (iOS 27) → Run (⌘R)

# Or command line:
./scripts/build-ios-simulator.sh
```

Override simulator:

```bash
NOBS_SIMULATOR_NAME="iPhone 17" NOBS_SIMULATOR_OS=27.0 ./scripts/build-ios-simulator.sh
```

Point the app at Tank in **Privacy** (URL + same `NOBS_DEVICE_TOKEN` as `.env`).

### Simulator-only QA (no Tank)

Onboarding, Today + Calendar/Reminders, widget, App Intents, deep links (`nobs://today`, `nobs://chat`), accessibility. See [`IOS_SESSION_HANDOFF.md`](IOS_SESSION_HANDOFF.md).

### Physical iPhone (deferred blocker)

Automatic signing uses team `K853LKQLAS`. Widget extension must share App Group + team. Archive requires valid distribution profiles with App Groups and Sign in with Apple enabled on both App IDs. See [Apple Developer / signing state](#apple-developer--signing-state).

### Website

```bash
cd website && pnpm install && pnpm build
```

### Local AI stack (Tank or dev machine)

```bash
./scripts/setup-local-ai.sh   # Ollama models, Aider, Open WebUI venv
```

---

## How to test

### Commands that pass on a healthy dev machine

| Check | Command | Expected |
|-------|---------|----------|
| Backend tests + lint | `python3 scripts/dev.py check` | 103 passed, ruff clean |
| iOS unit tests | `bash scripts/test-ios.sh` | NOBSTests green (needs simulator + Xcode beta) |
| iOS compile | `./scripts/build-ios-simulator.sh` | Build succeeded |
| Website | `cd website && pnpm build` | Vite production build |
| Docs whitespace | `git diff --check` | No conflict markers or trailing issues |

Backend CI runs the same `dev.py check` on **Tank** (Python 3.12) and **Mac** (Python 3.13). iOS CI runs `scripts/test-ios.sh` on the Mac runner with `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`.

---

## CI/CD

### Workflows

| Workflow | Trigger | Runner | What it does |
|----------|---------|--------|--------------|
| **Backend CI** | PR + push to `main` | `self-hosted, tank` (Python 3.12); `self-hosted, macOS, ARM64` (Python 3.13 + NOBSTests) | `dev.py setup` + `dev.py check`; `test-ios.sh` |
| **TestFlight** | Push to `main` (iOS paths) + `workflow_dispatch` | `self-hosted, macOS, ARM64, testflight` | API cert provisioning, archive, export, upload |
| **Auto-approve safe PRs** | `pull_request_target` | `self-hosted, tank` | Dependabot patch/minor; docs-only from collaborators |

### Self-hosted runners

| Runner labels | Host | Setup script |
|---------------|------|--------------|
| `self-hosted, tank` | Linux Tank homelab | `scripts/setup-github-runner-tank.sh` |
| `self-hosted, macOS, ARM64` | Mac (backend + iOS tests) | `scripts/setup-github-runner-mac.sh` |
| `self-hosted, macOS, ARM64, testflight` | Mac (archive/upload) | Same Mac runner with extra label |

### GitHub secrets (names only — never commit values)

| Secret | Used by |
|--------|---------|
| `ASC_API_KEY_ID` | TestFlight workflow |
| `ASC_API_ISSUER_ID` | TestFlight workflow |
| `ASC_API_KEY_CONTENT` | TestFlight workflow (`.p8` key, plain or base64) |
| `GITHUB_TOKEN` | Auto-approve workflow (default) |

**Not required anymore:** `DIST_CERT_P12` — certs are provisioned via App Store Connect API in CI.

### TestFlight `workflow_dispatch` options

| Input | Effect |
|-------|--------|
| `refresh_signing_only` | Refresh certs/profiles; skip archive/upload |
| `cleanup_apple_account` | Destructive: remove non-NOBS certs/profiles/bundle IDs |
| `upload_staged_ipa` | Upload `~/nobs-build/NOBS.ipa` only (skip build) |

Local staging before upload-only dispatch:

```bash
./scripts/stage-testflight-ipa.sh
# Then run workflow with upload_staged_ipa=true
```

### Signing approach (CI)

1. Ephemeral CI keychain (`scripts/ci-prepare-keychain.sh`)
2. Install ASC API key to `~/private_keys/`
3. `scripts/ci-ensure-signing-certs.sh` — iPhone Developer + Apple Distribution via API
4. `scripts/ci-refresh-provisioning-profiles.sh` — fastlane sigh, App Store profiles
5. `scripts/ci-enable-bundle-capabilities.py` — App Groups + Sign in with Apple (best-effort)
6. `xcodebuild archive` + export with `CODE_SIGN_STYLE=Automatic`, `-allowProvisioningUpdates`
7. `xcrun altool --upload-app` to TestFlight

`ExportOptions.plist`: `method=app-store-connect`, `signingStyle=automatic`, `teamID=K853LKQLAS`.

### Xcode Cloud (separate from GitHub)

Check **NOBS | Default | Build - iOS** in PRs — Apple's builders on App Store Connect. Often fails with `action_required` when App ID capabilities (App Groups, Sign in with Apple) are not enabled in the Developer portal. Fix portal first, then re-run in ASC.

---

## Apple Developer / signing state

| Item | State |
|------|-------|
| Team ID | `K853LKQLAS` |
| App IDs | `com.nobsdash.nobs`, `com.nobsdash.nobs.widgets` |
| App Group | `group.com.nobsdash.nobs` — must exist and be assigned to both IDs |
| Sign in with Apple | Required on main app ID |
| CI signing | Automated via ASC API (no manual `.p12` in secrets) |
| Local device signing | **Blocked at home** — development/distribution profiles need portal capabilities |
| Physical TestFlight upload | **Pending** — archive works once portal + profiles align |
| Export compliance | `ITSAppUsesNonExemptEncryption=false` (HTTPS only) |

**Manual steps (home):** Enable App Group + Sign in with Apple on both identifiers at [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list). Profiles regenerate on next automatic build. Full checklist: [`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md).

**Scripts for signing maintenance:**

- `scripts/refresh-app-store-connect-signing.sh` — local signing refresh
- `scripts/validate-asc-api.py` — verify API key access
- `scripts/ci-cleanup-apple-account.py` — NOBS-only cleanup (CI dispatch)

---

## Environment variables and secrets

All backend settings use prefix `NOBS_` (see `.env.example` and `app/config.py`).

| Variable | Purpose |
|----------|---------|
| `NOBS_ENVIRONMENT` | `development` / production label |
| `NOBS_DATABASE_URL` | Main SQLite URL |
| `NOBS_VERSION` | API version string |
| `NOBS_OLLAMA_BASE_URL` | Ollama HTTP endpoint |
| `NOBS_OLLAMA_MODEL` | Chat model name |
| `NOBS_CODING_MODEL` | Developer-mode model |
| `NOBS_OLLAMA_TIMEOUT_SECONDS` | Model call timeout |
| `NOBS_DEVICE_TOKEN` | **Required** for `/ready`, `/chat`, agent routes |
| `NOBS_AGENT_DATABASE_PATH` | Agent SQLite path |
| `NOBS_AGENT_WORKSPACE_PATH` | Agent workspace root |
| `NOBS_AGENT_PROJECT_PATH` | Developer-mode project root |
| `NOBS_AGENT_MAX_STEPS` | Agent tool loop bound |
| `NOBS_DASHBOARD_NAME` | Dashboard display name |
| `NOBS_TIMEZONE` | Scheduler / overnight window TZ |
| `NOBS_OVERNIGHT_QUEUE_ENABLED` | Overnight task queue toggle |
| `NOBS_OVERNIGHT_WINDOW_START` / `END` | Overnight window (HH:MM) |
| `NOBS_OVERNIGHT_IDLE_CPU_PERCENT` | CPU threshold for overnight work |
| `NOBS_HOMEASSISTANT_URL` | Home Assistant base URL |
| `NOBS_HOMEASSISTANT_TOKEN` | HA long-lived token |
| `NOBS_WEATHER_LATITUDE` / `LONGITUDE` | Weather tool location |
| `NOBS_NEWS_FEED_URLS` | Comma-separated RSS feeds |
| `NOBS_WEB_SEARCH_MAX_RESULTS` | Web search cap |
| `NOBS_DREAM_TEAM_*` | Dream Team Sandbox (local Ollama, max agents/iterations) |
| `NOBS_WORKPLACE_*` | Live workplace dashboard + browser allowlist |

CI-only (not in `.env.example`): `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`, `ASC_API_KEY_CONTENT`, `CI_KEYCHAIN_PASSWORD`, `DEVELOPER_DIR`, `DEVELOPMENT_TEAM`.

### Tank fresh start

Reset Tank to a first-time client (no pairing, sessions, or cached briefings):

```bash
bash scripts/reset-tank-fresh.sh
```

Backs up to `data/backups/pre-reset-<timestamp>/`, wipes client state under `data/`, clears `NOBS_DEVICE_TOKEN`, re-inits the agent DB schema, and restarts the service. Homelab: `bash scripts/reset-tank-fresh.sh --remote`. Full wipe/preserve list: [`TANK_FRESH_START.md`](TANK_FRESH_START.md).

---

## Tank API surface (quick reference)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/health` | Public | Liveness |
| GET | `/ready` | Device token | Ollama + DB readiness |
| POST | `/chat` | Device token | Ollama chat with route + privacy receipt |
| POST | `/auth/apple` | — | Sign in with Apple token exchange |
| POST | `/briefing` | Device token | Tank briefing generation |
| GET | `/briefing/latest` | Device token | Latest stored briefing |
| POST | `/agent/tasks` | Device token | Run agent task |
| GET | `/agent/approvals` | Device token | Pending approvals |
| POST | `/agent/approvals/{id}` | Device token | Approve/deny |
| GET | `/agent/proposals` | Device token | Agent proposals |
| POST | `/agent/proposals/{id}/decide` | Device token | Proposal decision |
| GET/POST/PATCH | `/schedules` | Device token | Briefing schedules |
| POST/GET | `/overnight/tasks` | Device token | Overnight queue |
| POST | `/sync/calendar`, `/sync/reminders` | Device token | iOS sync |
| GET | `/dashboard`, `/dashboard/status` | Public / token | Connected-screen UI |
| GET | `/workplace`, `/workplace/status` | Public | Animated dream-team floor + monitor state |
| POST | `/workplace/browser/sessions` | Device token | Start filtered browser sandbox session |
| GET | `/workplace/browser/sessions/{id}/screenshot` | Public | SVG screenshot poll for monitor tile |
| POST | `/dream-team/sessions` | Device token | Start dream team sandbox session |
| POST | `/dream-team/sessions/{id}/run` | Device token | Draft/test/refine locally via Ollama |
| GET | `/dream-team/proposals` | Device token | Pending team proposals for review |
| POST | `/dream-team/proposals/{id}/decide` | Device token | Approve/reject proposed team |
| GET | `/dream-team/policy` | Device token | Local-first processing metadata |

### Dream Team Sandbox (v1)

Tank-side module that drafts agent personas, sandbox-tests them with **read-only local tools only**, scores with heuristics (no extra LLM calls), refines low-scoring drafts (max 2 iterations), and proposes a team for user approval. All inference uses local Ollama (`qwen3:8b` by default); no cloud/PCC/external APIs in the refinement loop. Approved members are stored as JSON manifests under `data/dream-team/active/`. Deploy: `bash scripts/deploy-dream-team.sh`.

### Live workplace dashboard (v1)

`app/workplace.py` + `workplace/` static UI show running dream-team drafts and approved agents on an animated floor (distinct colors/icons, CSS movement between lobby/desks/monitors). Browser use goes through a **filtered allowlist sandbox** (`NOBS_WORKPLACE_BROWSER_ALLOWED_DOMAINS`); v1 uses SVG screenshot polling, not video. Open `http://<tank>:8000/workplace` on the LAN. Dream-team session state is read from `/dream-team/*` store tables and `data/dream-team/active/` manifests — no changes to the sandbox refinement loop.

Full agent policy: [`TANK_AGENT_CORE.md`](TANK_AGENT_CORE.md).

---

## Recent changes and branch state

**Default branch:** `main` (up to date with `origin/main` as of July 10, 2026).

**Recent `main` commits (signing + release prep):**

- Consolidated GitHub Actions into single TestFlight workflow
- TestFlight signing via App Store Connect API only (dropped `DIST_CERT_P12`)
- API scripts for cert provisioning, profile refresh, bundle capability enablement
- iOS marketing version bumped to **4.0** (build 1)
- Apple Developer account cleanup scripts for NOBS-only signing hygiene

**Active remote branches (examples):** `claude/ios-visual-polish`, various `human/*` feature branches (ios-approval-live-activity, tank-ops-hardening, etc.).

**Not merged / in progress:** Physical iPhone validation, TestFlight upload to App Store Connect, long-term memory, NOBScloud, household identity.

---

## Known issues and where to look

| Issue | Symptom | Fix / doc |
|-------|---------|-----------|
| App ID capabilities missing | Xcode Cloud `action_required`; archive wants App Groups / SIWA profiles | [`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md) § Provisioning |
| TestFlight archive fails | No iOS Development cert / profile errors | [`CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md) § TestFlight |
| `docs-only-auto-approve` red in ~2s | Billing/spending message, `ubuntu-latest`, zero steps | Re-run after `main` has tank runner; see [`CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md) |
| `tank.local` unresolved | Device cannot reach Tank | Use LAN IP (e.g. `http://192.168.1.x:8000`) |
| PCC badge hidden | Apple Cloud route exists but badge gated | [`PCC_INTEGRATION.md`](PCC_INTEGRATION.md), `PCCFeatureFlags.swift` |
| Memory / Home tabs placeholder | `ComingSoonView` | [`CURRENT_STATE.md`](CURRENT_STATE.md) § Not working yet |
| mDNS / pairing | QR works; hostname may not | `scripts/pairing.py`, NOBSTankMac QR |

---

## Product decisions (summary)

Full detail: [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). Headlines:

- **Local-first, privacy-first** — useful without paid cloud; no data sales or surveillance ads.
- **Chat is home** — Today, Memory, Home, Activity, Privacy are contextual views.
- **Processing labels** — every response shows Local, Tank, or NOBScloud where applicable.
- **Approvals** — state-changing Tank tools require explicit user approval; atomic and audited.
- **Contexts** — Personal, Business, Shared; no silent cross-context sharing.
- **Accessibility** — adaptive behavior (response length, VoiceOver, Dynamic Type), not a separate mode.
- **Smart home** — Home Assistant bridge first; Google Home APIs later ([`GOOGLE_HOME_INTEGRATION.md`](GOOGLE_HOME_INTEGRATION.md)).
- **Launch persona** — overwhelmed working adult; anchor experience is morning briefing → realistic plan.

---

## If you're an AI agent working on this repo, read this first

1. **Read before coding:** [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) → [`CURRENT_STATE.md`](CURRENT_STATE.md) → this file → topic doc under `docs/`.
2. **Minimal scope** — smallest correct diff; do not refactor or expand unrelated code.
3. **Match conventions** — read surrounding code; Swift 6 / SwiftUI patterns in `NOBS/`; FastAPI modules in `app/`; existing script style in `scripts/`.
4. **Do not commit unless asked** — user rule; push only when requested for handoff.
5. **Never commit secrets** — `.env`, keys, tokens, certs, personal data, DerivedData, caches.
6. **Honest boundaries** — do not claim unfinished features work; label coming soon.
7. **Cross-platform** — backend must run on Linux, macOS, Windows/WSL2; no macOS-only paths in shared Python.
8. **Agent tools** — register in `agent_tools.py`; read-only auto-run only when bounded; state changes need approval queue.
9. **Validation** — run `python3 scripts/dev.py check` for backend; `build-ios-simulator.sh` / `test-ios.sh` for iOS when on Mac with Xcode.
10. **Update handoff docs** — if capability status changes, update [`CURRENT_STATE.md`](CURRENT_STATE.md) in the same change.
11. **Branch protocol** — `git pull --ff-only`; one branch per task (`codex/`, `claude/`, `human/`); no force-push without explicit approval.
12. **Source-of-truth order:** user request → PRODUCT_DECISIONS → architecture docs → tests → [`AI_WORKFLOW.md`](AI_WORKFLOW.md).

Tool adapters (`AGENTS.md`, `CLAUDE.md`) point to [`AI_WORKFLOW.md`](AI_WORKFLOW.md) — do not duplicate rules there.

---

## Deeper documentation

| Topic | Document |
|-------|----------|
| Product direction | [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) |
| What ships today | [`CURRENT_STATE.md`](CURRENT_STATE.md) |
| Agent / contributor workflow | [`AI_WORKFLOW.md`](AI_WORKFLOW.md) |
| iOS session handoff | [`IOS_SESSION_HANDOFF.md`](IOS_SESSION_HANDOFF.md) |
| CI failures | [`CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md) |
| TestFlight / App Store | [`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md) |
| Tank build & ops | [`NOBS_TANK_BUILD.md`](NOBS_TANK_BUILD.md) |
| Agent architecture | [`TANK_AGENT_CORE.md`](TANK_AGENT_CORE.md) |
| Dashboard / kiosk | [`TANK_DASHBOARD.md`](TANK_DASHBOARD.md) |
| PCC / Apple Cloud | [`PCC_INTEGRATION.md`](PCC_INTEGRATION.md), [`PCC_ENTITLEMENT_CHECKLIST.md`](PCC_ENTITLEMENT_CHECKLIST.md) |
| Smart home | [`GOOGLE_HOME_INTEGRATION.md`](GOOGLE_HOME_INTEGRATION.md) |
| External config sync | [`EXTERNAL_CONFIG_SYNC.md`](EXTERNAL_CONFIG_SYNC.md) |
| Website deploy | [`NOBSDASH_DEPLOYMENT.md`](NOBSDASH_DEPLOYMENT.md) |
| Public release checklist | [`PUBLIC_RELEASE.md`](PUBLIC_RELEASE.md) |
| Requirements | [`PRD.md`](PRD.md) |
| Backlog | [`ISSUE_BACKLOG.md`](ISSUE_BACKLOG.md) |

---

## Verification snapshot (July 10, 2026)

```bash
python3 scripts/dev.py check    # 103 passed, ruff clean (verified)
./scripts/build-ios-simulator.sh   # requires Xcode 27 beta + iOS 27 simulator
bash scripts/test-ios.sh           # NOBSTests on Mac CI runner
```

Repository tests prove code behavior; live Tank deployment facts require a live check on the homelab host.
