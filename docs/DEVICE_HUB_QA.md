# NOBS Device Hub QA Matrix

**Status:** Active iOS/iPadOS compatibility matrix  
**Updated:** July 2, 2026  
**Xcode:** 27.0 beta (`27A5209h`)  
**SDK:** iOS/iPadOS Simulator 27.0

Device Hub centralizes simulated and physical Apple destinations. Repeatable checks still run through `xcodebuild` and `simctl` so the same matrix can be exercised without relying on one developer's open Xcode window.

## Supported product targets

| Platform | Current status | Boundary |
|---|---|---|
| iPhone | Supported prototype | Primary launch surface |
| iPad | Supported universal prototype | Uses a centered, readable chat column |
| Physical iPhone/iPad | Pending signed-device validation | Requires an Apple development team and connected hardware |
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

## Release blockers

The prototype is not yet “works on any device” and must not be described that way externally. Before a public beta:

- [ ] Run the approve, reject, undo, and privacy-receipt paths through an automated UI test.
- [ ] Validate on at least one physical iPhone.
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
