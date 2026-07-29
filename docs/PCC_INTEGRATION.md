# Private Cloud Compute Integration (v1.1)

**Status:** Implemented (routing + UI scaffolding; badge gated until entitlement QA)

**Reviewed:** July 9, 2026

## Summary

NOBS v1.1 adds a policy-driven `ModelRouter` that adapts between **Local**, **Tank**, **Apple Cloud (PCC)**, and **NOBScloud** based on availability, user preferences, and task signals. PCC integration uses Apple's `PrivateCloudComputeLanguageModel` through the Foundation Models framework.

This does **not** block v1.0 beta. Routing and badges remain off until you enable feature flags after entitlement approval.

## Verified Apple API (WWDC 2026)

| Item | Value |
|------|-------|
| OS floor | iOS 27, macOS 27, watchOS 27, visionOS 27 |
| Swift type | `PrivateCloudComputeLanguageModel()` |
| Session | `LanguageModelSession(model: PrivateCloudComputeLanguageModel())` |
| Entitlement | `com.apple.developer.private-cloud-compute` |
| Developer cost | Free for App Store Small Business Program + <2M first-time downloads |
| User limits | Daily quota per iCloud account; iCloud+ upgrade path |
| Context | 32K tokens (vs 4K/8K on-device) |
| Reasoning | `.light`, `.moderate`, `.deep` via `ContextOptions` |

Sources:

- [Adding server-side intelligence with Private Cloud Compute](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute)
- [Accessing Private Cloud Compute](https://developer.apple.com/private-cloud-compute/)
- [WWDC26 session 319](https://developer.apple.com/videos/play/wwdc2026/319/)

## Architecture

```text
AppModel.send / generateBriefing
        │
   ModelRouter.route(request, context)
        │
   ┌────┴────┬──────────┬────────────┐
   │         │          │            │
 Local    Apple Cloud   Tank      NOBScloud
 (FM)     (PCC)         (HTTP)    (paid → PCC fallback)
```

### Key files

| File | Role |
|------|------|
| [`NOBS/Services/ModelRouter.swift`](../NOBS/Services/ModelRouter.swift) | Policy scoring and route selection |
| [`NOBS/Services/RoutingPreferences.swift`](../NOBS/Services/RoutingPreferences.swift) | Tank-offline behavior persistence |
| [`NOBS/Services/AppleModelProvider.swift`](../NOBS/Services/AppleModelProvider.swift) | Foundation Models adapter (on-device + PCC) |
| [`NOBS/Services/LocalAssistant.swift`](../NOBS/Services/LocalAssistant.swift) | iOS on-device FM wrapper |
| [`NOBS/Services/PCCFeatureFlags.swift`](../NOBS/Services/PCCFeatureFlags.swift) | Entitlement / routing / badge gates |
| [`NOBS/AppModel.swift`](../NOBS/AppModel.swift) | Executes routing decisions |
| [`NOBS/Views/PCCQuotaStatusView.swift`](../NOBS/Views/PCCQuotaStatusView.swift) | Quota UX per Apple guidance |
| [`NOBSTests/ModelRouterTests.swift`](../NOBSTests/ModelRouterTests.swift) | Routing fixture tests |

## Router decision table

| Condition | Route |
|-----------|-------|
| Tank reachable | Tank (preserves current behavior) |
| Tank offline + `askEachTime` | Prompt user once per session pattern |
| Tank offline + `localOnly` | Local (FM or templates) |
| Tank offline + `useAppleCloud` + PCC available + entitled | Apple Cloud |
| Tank offline + `useNOBScloud` + subscribed + `cloudOk` + PCC available | Apple Cloud (paid fallback; receipt names NOBScloud) |
| Tank offline + `useNOBScloud` + subscribed + `cloudOk` + PCC unavailable | Local with honest “capacity unavailable” message |
| Tank offline + `queueForTank` | Local with queue messaging |
| User says "think harder" + PCC available | Apple Cloud (one-shot or policy) |
| PCC quota exceeded | Fall back to Local; disable send when Apple Cloud-only |

## Conversational preference learning

When Tank is offline and behavior is `askEachTime`, NOBS prompts:

> Tank isn't home right now. I can stay local… use Apple's private cloud… wait for Tank… or use NOBScloud…

User replies (persisted in `routing-preferences.json`):

- `stay local`
- `use apple cloud`
- `wait for tank`
- `use nobscloud`
- `reset routing`

## Privacy receipts

| Route | `processed` field |
|-------|-------------------|
| Local | `Local on this iPhone` or `(on-device model)` |
| Apple Cloud | `Apple Private Cloud Compute (not stored after request)` |
| Tank | `Tank on your private network` |
| NOBScloud (delivered) | `Apple Private Cloud Compute (NOBScloud paid fallback; …)` |
| NOBScloud (unavailable) | Local receipt + chat explanation |

## Feature flags (honesty gate)

| Plist key | Default | Meaning |
|-----------|---------|---------|
| `NOBSPCCEntitlementConfigured` | off | Developer entitlement active |
| `NOBSPCCRoutingEnabled` | off | Allow PCC in ModelRouter |
| `NOBSPCCShowBadge` | off | Show "Apple Cloud" badge in UI |

Until all three are enabled after QA, Privacy shows **Apple private cloud — coming soon**.

See [PCC_ENTITLEMENT_CHECKLIST.md](PCC_ENTITLEMENT_CHECKLIST.md).

## Device requirements

PCC requires **Apple Intelligence** (iPhone 15 Pro+, iPhone 16+, etc.). Older iPhones continue on local templates + optional Tank — no hardcoded device list; use `PrivateCloudComputeLanguageModel().availability`.

## PCC vs NOBScloud

| | Apple Cloud (PCC) | NOBScloud |
|--|-------------------|-----------|
| Cost to developer | Free (eligible) | Subscription via IAP; compute via Apple PCC for now |
| Cost to user | Apple Intelligence quota | Subscription |
| Best for | Private reasoning burst, 32K context | Paid Tank-away fallback today; hosted research later |

## Testing

```bash
xcodebuild test -project NOBS.xcodeproj -scheme NOBS -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Xcode scheme → Run → Options → **Simulated Apple Foundation Models Availability** for quota states.

## v1.0 vs v1.1

| v1.0 gate | v1.1 (this work) |
|-----------|------------------|
| Build/signing fix | ModelRouter + AppleModelProvider |
| Tank-first chat | Adaptive policy routing |
| Template local fallback | On-device FM when available |
| — | PCC behind feature flags |
| — | Quota UX + entitlement checklist |
