# App Privacy nutrition labels (draft)

Complete the questionnaire in App Store Connect. This is the intended honest mapping for the beta build, including StoreKit tips/subscription and the Apple Private Cloud Compute (PCC) paid fallback shipped in `AppleModelProvider.swift` / `ModelRouter.swift`.

## Data linked to you
| Data type | Collected | Purpose | Notes |
|-----------|-----------|---------|-------|
| Name | Optional | App functionality | Onboarding display name, stored on device |
| User ID | Optional | App functionality | Sign in with Apple identifier for Tank auth |
| Calendar | Optional | App functionality | Same-day events for briefing; not uploaded to NOBS servers |
| Other user content | Optional | App functionality | Chat text; processed Local, user-configured Tank, or — only when routed to Apple Cloud (see below) — Apple Private Cloud Compute. Briefing text is not part of this: `AppModel.generateBriefing()` only builds locally or refines through the user's own Tank; it never calls `ModelRouter`/`AppleModelProvider`. |

## Data not collected for NOBS company servers
NOBS does not operate a mandatory cloud backend in this beta. Tank is user-controlled infrastructure. `StoreKitService` only reads verified `Transaction.currentEntitlements` on-device to gate the NOBScloud UI (`hasNOBScloud`); tip and subscription transaction data is never transmitted to a NOBS server, so per App Store Connect's definition of "collection" (off-device transmission beyond servicing the immediate purchase), purchase/transaction history is **not** a collected data type here — Apple retains and processes payment records itself.

## Data used to track you
**None** — no tracking across apps or websites.

## Local network
Used only when the user configures a Tank URL to reach their private server.

## Third-party AI / processing destinations
- **Tank (user-controlled):** when connected, chat may be processed on the user's own Tank with local Ollama. No OpenAI/Anthropic by default.
- **Apple Private Cloud Compute (Apple, not NOBS-operated):** chat text only, never briefing. Two distinct routes can send a request to PCC, both gated by `PCCFeatureFlags.routingEnabled` + `developerEntitlementConfigured` + on-device PCC availability + quota (`ModelRouter.pccDecision`):
  1. **Direct "Apple Cloud" preference** — any user who sets the Tank-offline preference to "use apple cloud," or explicitly asks to escalate, can trigger PCC. This does **not** require a NOBScloud subscription.
  2. **NOBScloud paid subscription fallback** — when Tank is unavailable, the user's privacy comfort allows cloud (`privacyComfort == .cloudOk`), and the subscription is active (`hasNOBScloud`), the same PCC path serves as paid capacity (`ModelRouter.cloudDecision`).

  Apple states PCC data is not stored after the request and is not used to train models. The top-level Local/Tank/Apple Cloud route badge only shows "Apple Cloud" when `PCCFeatureFlags.showBadgeInUI` is also true (`NOBSPCCRoutingEnabled` **and** `NOBSPCCEntitlementConfigured` **and** `NOBSPCCShowBadge`) — see the requirement added to [`PCC_ENTITLEMENT_CHECKLIST.md`](../PCC_ENTITLEMENT_CHECKLIST.md) to enable that flag alongside routing before shipping, so a production build never runs PCC while the badge still reads "Local." The detailed privacy receipt (`PrivacyReceiptView`) always shows the true `processed` destination regardless of the badge flag. PCC is off entirely until `NOBSPCCRoutingEnabled` + entitlement QA are turned on for a build.
