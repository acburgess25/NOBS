# NOBS Device Hub QA Matrix

**Status:** Active iOS/iPadOS compatibility matrix  
**Updated:** July 8, 2026  
**Xcode:** 27.0 beta (`27A5209h`)  
**SDK:** iOS/iPadOS Simulator 27.0

Device Hub centralizes simulated and physical Apple destinations. Repeatable checks still run through `xcodebuild` and `simctl` so the same matrix can be exercised without relying on one developer's open Xcode window.

## Supported product targets

| Platform | Current status | Boundary |
|---|---|---|
| iPhone | Supported prototype | Primary launch surface |
| iPad | Supported universal prototype | Uses a centered, readable chat column |
| Physical iPhone/iPad | Validation framework ready | Requires an Apple development team and connected hardware; see [Physical device E2E](#physical-device-e2e-validation) and [`PHYSICAL_DEVICE_QA.md`](PHYSICAL_DEVICE_QA.md) |
| macOS | Future product target | Not certified by the current iOS target |
| visionOS | Future product target | Requires a separate spatial interaction design and target |
| watchOS | Future product target | Requires focused glanceable workflows and a separate target |
| Android / Windows / web | Unsupported by Device Hub | Requires separate clients; shared backend contracts remain platform-neutral |

Device Hub does not make one SwiftUI target work on every computing platform. It manages Apple destinations. NOBS should share schemas, services, and product rules across platforms while giving each client an honest native boundary.

## Current build matrix

All destinations below completed a clean simulator build on July 2, 2026.

| Destination | Role | Build | Launch/render | Notes |
|---|---|---|---|---|
| iPhone 17e | Compact iPhone | Pass | Pass | Conflict and primary action are visible in the first viewport |
| iPhone 17 Pro | Reference iPhone | Pass | Pass | Baseline simulator used during implementation |
| iPhone 17 Pro Max | Large iPhone | Pass | Build verified | Launch screenshot not yet retained |
| iPad mini (A17 Pro) | Compact iPad | Pass | Build verified | Universal target enabled |
| iPad Pro 13-inch (M5) | Large iPad | Pass | Pass | Chat constrained to a 720-point reading column |

## Working demo behavior

- Shows a 30-minute conflict between client preparation and a fixed call.
- Offers a locally processed revised plan.
- Keeps the conflict explanation visible and plainspoken.
- Provides approve and reject paths.
- States when nothing changed.
- Offers a privacy receipt describing sample inputs, processing route, sharing, and change behavior.
- Labels the experience as a preview using sample data.

## Commands

Reference build:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project NOBS.xcodeproj -scheme NOBS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  -derivedDataPath /tmp/NOBSDerivedData build
```

Replace the destination with each Device Hub simulator name to repeat the matrix. Use a unique derived-data directory when builds run concurrently.

## Physical device E2E validation

Simulator builds prove compilation and basic UI. A physical iPhone is required to prove Keychain persistence, LAN pairing, widget timelines on a real Home Screen, Siri, and notification delivery.

**Prerequisites**

| Item | Notes |
|---|---|
| Apple development team | Device must be registered in Xcode; app signed for debug or TestFlight |
| Tank on LAN | `nobs-api` running; iPhone and Tank on the same network |
| Pairing surface | Tank dashboard QR at `http://<tank-host>:8000/dashboard`, or `python3 scripts/pairing.py` in the repo root |
| iOS app path | Privacy → **Scan QR** (or open `nobs://pair?url=…&token=…` from QR) |

**Structured checklist** (record pass/fail in [`PHYSICAL_DEVICE_QA.md`](PHYSICAL_DEVICE_QA.md)):

| # | Area | What to verify |
|---|---|---|
| 1 | **Pairing — dashboard QR** | Scan QR on Tank dashboard; app shows connected Tank URL; `/ready` succeeds |
| 2 | **Pairing — `scripts/pairing.py`** | Terminal QR pairs the same device; token stored in Keychain survives app kill |
| 3 | **Pairing — manual URL** | Privacy → Tank address + token entry works when QR is unavailable |
| 4 | **Chat** | Send message; Tank route badge and privacy receipt visible; reply returns from Tank |
| 5 | **Briefing refinement** | Today → generate briefing; on-device first, Tank refinement when connected; snapshot written |
| 6 | **Approve / deny** | Activity → pending approval; Approve and Deny both update queue and show receipt |
| 7 | **Calendar sync** | Grant calendar access; events appear on Today; `/sync/calendar` succeeds (check Tank logs or dashboard activity) |
| 8 | **Reminders sync** | Grant reminders access; briefing includes reminders when permitted; `/sync/reminders` succeeds |
| 9 | **Widget snapshot** | After briefing, Home Screen widget shows topline from `widget-snapshot.json` without launching app |
| 10 | **App restart reconnect** | Force-quit app; relaunch on same network — saved Tank URL and token reconnect without re-pairing |
| 11 | **Offline honesty** | Disable Wi‑Fi or stop Tank; chat shows Local route and honest fallback (no silent failure) |
| 12 | **Reconnect** | Restore network/Tank; status returns to connected without manual re-pair |

**Automation boundary**

| Can automate (simulator / CI) | Requires physical hardware |
|---|---|
| `xcodebuild build` per destination | Keychain token persistence across reinstall |
| Future `NOBSTests` unit tests (TankClient decode, snapshot writer) | QR scan and `nobs://pair` deep link |
| Future UI test: onboarding → Today smoke | Real Home Screen / Lock Screen widget refresh |
| Backend `python3 scripts/dev.py check` | Siri phrases and notification actions |
| Dashboard pairing URL generation (API test) | LAN discovery when `tank.local` does not resolve |

## Release blockers

The prototype is not yet “works on any device” and must not be described that way externally. Before a public beta:

- [ ] Run the approve, reject, undo, and privacy-receipt paths through an automated UI test.
- [ ] Complete physical iPhone checklist in [`PHYSICAL_DEVICE_QA.md`](PHYSICAL_DEVICE_QA.md) on at least one device.
- [ ] Validate on a physical iPad if iPad is included in the first beta.
- [ ] Test light and dark appearance.
- [ ] Test standard and accessibility Dynamic Type sizes.
- [ ] Test VoiceOver reading and focus order.
- [ ] Test reduced motion and increased contrast.
- [ ] Test rotation, multitasking, and narrow iPad windows.
- [ ] Test offline, Tank-offline, and cloud-disabled states.
- [ ] Test permission denied, limited, and granted states once real integrations exist.
- [ ] Confirm that sample-only language disappears only when real data paths replace it.

## Evidence standard

A successful build proves compilation for a destination. A successful launch and screenshot prove only the rendered state inspected. Neither proves all interaction, accessibility, privacy, networking, or physical-device behavior. Each release claim must match the evidence above.
