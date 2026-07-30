# App Privacy nutrition labels (draft)

Complete the questionnaire in App Store Connect. This is the intended honest mapping for the beta build, including StoreKit tips/subscription and the Apple Private Cloud Compute (PCC) paid fallback shipped in `AppleModelProvider.swift` / `ModelRouter.swift`.

## Data linked to you
| Data type | Collected | Purpose | Notes |
|-----------|-----------|---------|-------|
| Name | Optional | App functionality | Onboarding display name, stored on device |
| User ID | Optional | App functionality | Sign in with Apple identifier for Tank auth |
| Calendar | Optional | App functionality | Same-day events for briefing; not uploaded to NOBS servers |
| Other user content | Optional | App functionality | Chat text; processed Local, user-configured Tank, or (only when subscribed) Apple Private Cloud Compute |
| Purchase history | Required (when IAP is used) | App functionality | Apple StoreKit tip/subscription transactions; entitlement (`hasNOBScloud`) is tracked on-device only and is not sent to a NOBS server |

## Data not collected for NOBS company servers
NOBS does not operate a mandatory cloud backend in this beta. Tank is user-controlled infrastructure. Purchases are processed and recorded by Apple; NOBS never sees payment details and does not run its own purchase-analytics backend.

## Data used to track you
**None** — no tracking across apps or websites.

## Local network
Used only when the user configures a Tank URL to reach their private server.

## Third-party AI / processing destinations
- **Tank (user-controlled):** when connected, chat/briefing may be processed on the user's own Tank with local Ollama. No OpenAI/Anthropic by default.
- **Apple Private Cloud Compute (Apple, not NOBS-operated):** only when Tank is unavailable, the user's privacy comfort allows cloud processing, and an active NOBScloud subscription entitles the paid fallback, chat/briefing text may be sent to Apple's Private Cloud Compute for that single request. Apple states PCC data is not stored after the request and is not used to train models. This route is visibly labeled "Apple Private Cloud Compute" in the app's Local/Tank/Apple Cloud badge and privacy receipt (see `PrivacyReceipt.applePrivateCloud` / `.nobscloudPaidAppleCloud`) — it never happens silently, and it is off entirely until `NOBSPCCRoutingEnabled` + entitlement QA (`PCCFeatureFlags`) are turned on for a build.
