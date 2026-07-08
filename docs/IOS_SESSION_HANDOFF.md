# iOS session handoff

**Last updated:** July 8, 2026  
**Purpose:** Fast context for any agent or contributor picking up NOBS iPhone work mid-stream.

Read first: [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) (product truth), [`CURRENT_STATE.md`](CURRENT_STATE.md) (Apple app section), and [`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md) (TestFlight / review prep).

## Environment snapshot

| Item | Current |
|------|---------|
| Xcode | 27 beta (`/Applications/Xcode-beta.app`) |
| Simulator | iOS 27 — iPhone 17 Pro |
| Physical device | Signing broken at home; use Simulator until provisioning is fixed |
| Tank | Optional; local on-device briefing and calendar work without it |
| App Group | `group.com.nobsdash.nobs` |
| Bundle IDs | `com.nobsdash.nobs`, `com.nobsdash.nobs.widgets` |

## Open in Xcode

```bash
open /Users/ab/Documents/NOBS/NOBS.xcodeproj
```

Select the **NOBS** scheme and an **iPhone 17 Pro (iOS 27)** simulator destination, then Run (⌘R).

## Simulator build (no signing)

When automatic signing fails or you only need a compile check:

```bash
./scripts/build-ios-simulator.sh
```

Equivalent one-liner:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project NOBS.xcodeproj -scheme NOBS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  CODE_SIGNING_ALLOWED=NO build
```

Override simulator name or OS with environment variables:

```bash
NOBS_SIMULATOR_NAME="iPhone 17" NOBS_SIMULATOR_OS=27.0 ./scripts/build-ios-simulator.sh
```

## Physical iPhone signing (deferred)

Automatic signing is configured in the project (`DEVELOPMENT_TEAM = K853LKQLAS`). Known gaps:

- Widget extension (`NOBSWidgets`) must share the same team and App Group entitlements.
- CI uses manual distribution signing via `.github/workflows/testflight.yml`.
- Local device builds need a valid development certificate and provisioning profile for both targets.

**Do not block Simulator work on device signing.** Fix provisioning at home, then verify pairing, Tank chat, and widget reload on device.

## Simulator-only QA paths

These work without Tank:

1. **Onboarding** — conversational flow through name, load sources, hours, proactivity, and one problem.
2. **Today** — grant Calendar/Reminders in Simulator Settings; generate on-device Morning Briefing v2.
3. **Widget** — after a briefing exists, add the Home Screen / Lock Screen **Today's plan** widget; tap should open `nobs://today`.
4. **App Intents** — Shortcuts app → NOBS intents (Prepare my day, Explain schedule, Ask NOBS, Show privacy receipt).
5. **Deep links** — Safari `nobs://today`, `nobs://chat?prompt=...`, `nobs://privacy`.
6. **Accessibility** — VoiceOver labels on chat, onboarding, Today, widget, and approvals; Dynamic Type on briefing lists; response length shapes chat, Today, and widget density.

## Tank-dependent paths (skip at work)

- Sign in with Apple → Tank auth
- Tank chat refinement of briefings
- Calendar/reminders sync to `/sync/calendar` and `/sync/reminders`
- Approvals and Activity from `/agent/*`

Simulator defaults Tank address to `http://127.0.0.1:8000` when none is saved. Without a local API, the app stays in honest **Local** fallback.

## Key files

| Area | Files |
|------|-------|
| App shell | `NOBS/NOBSApp.swift`, `NOBS/ConversationView.swift` |
| State | `NOBS/AppModel.swift` |
| Today / briefing | `NOBS/Views/TodayView.swift`, `NOBS/AppModel.swift` (`generateBriefing`) |
| Onboarding | `NOBS/Views/OnboardingChatView.swift` |
| Widget | `NOBSWidgets/BriefingWidget.swift`, `NOBS/Services/BriefingSnapshotWriter.swift` |
| Design tokens | `NOBS/Color+NOBS.swift`, `NOBS/Views/NOBSTheme.swift`, `design/tokens.json` |
| App Store prep | `docs/APP_STORE_BETA_CHECKLIST.md`, `docs/app-store/*`, `website/public/privacy.html` |
| Smart home / Google | `docs/GOOGLE_HOME_INTEGRATION.md`, `app/home_assistant.py`, `app/agent_tools.py` |
| CI failures | `docs/CI_TROUBLESHOOTING.md` |
| Tank client | `NOBS/Services/TankClient.swift`, `NOBS/Services/TankConfiguration.swift` |
| Intents | `NOBS/Intents/NOBSAppIntents.swift` |
| Shared storage | `NOBS/Services/AppGroupStore.swift` |

## Recommended next slices

1. **TestFlight at home** — signing, archive, upload, external beta review (see [`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md)).
2. **Physical iPhone validation** — pairing, Tank reconnect, widget on Lock Screen.
3. **Fresh marketing screenshot** — Simulator capture for `website/public/nobs-app-preview.png`.
4. **Memory view** — replace `ComingSoonView` when approval workflow is ready.

## Handoff rule

When you finish a session, update this file and [`CURRENT_STATE.md`](CURRENT_STATE.md) if capability status changed. Name branch, commit, validation run, and remaining risks in your PR or final message.
