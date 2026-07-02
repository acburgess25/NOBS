# NOBS Product Requirements Document (PRD)

## 1. Executive Summary

NOBS is a privacy-first, local AI assistant platform for regular users in the Apple ecosystem. It provides a single conversation interface that becomes context-aware over time, performs useful proactive support, and preserves user trust by minimizing cloud dependence.

NOBS routes work transparently across on-device Apple models, user-owned Tank hardware, future NOBSbox hardware, and optional NOBScloud. Core local assistance remains useful for free. Paid services add capability rather than removing privacy or manufacturing hardware limits.

The detailed approved product direction lives in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). WWDC26 architecture changes live in [`WWDC26_IMPACT.md`](WWDC26_IMPACT.md).

---

## 2. Problem Statement

Most assistant products are:
- cloud-first with weak trust semantics
- overly complex for non-technical users
- reactive instead of genuinely helpful and proactive

Target users need:
- practical day-to-day support
- simple interfaces
- confidence that personal data remains private

---

## 3. Product Vision

**“The Apple ecosystem made actually smart for regular users.”**

NOBS should feel like:
- your own assistant, not a generic chatbot
- integrated with your device context
- understandable, controllable, and respectful

---

## 4. Product Principles

1. **Privacy by default**
2. **Local-first architecture**
3. **Conversation-first UX**
4. **High-signal proactivity, low-noise delivery**
5. **Transparent behavior and boundaries**
6. **Works with existing user hardware realities**

---

## 5. Target User and Positioning

### Primary audience
Everyday Apple users (including overwhelmed working adults) who want practical assistant value without becoming automation experts.

### Positioning
NOBS is not “yet another assistant app.” It is an intelligent Apple-native interaction layer that improves daily life while preserving user autonomy and privacy.

---

## 6. Core Experience

### Interface model
- Single iMessage-style chat
- No complex settings architecture
- Settings/personalization happen in conversation

### Context-aware operating states

| State | Behavior |
|---|---|
| Away + battery | Lightweight local mode, only important prompts |
| Away + plugged | Background prep for near-future schedule needs |
| Home + Wi‑Fi | Ambient assistance, home-aware tone |
| Home + plugged + tank online | Full-power deeper planning/analysis |

Context inputs:
- location
- calendar
- charging state
- home server availability

---

## 7. Functional Requirements (MVP Scope)

### FR-1: Conversation shell
- Chat interface with persistent history
- Message-level state and delivery reliability

### FR-2: Local inference baseline
- On-device generation/summarization path for free tier
- Graceful handling when local model unavailable

### FR-3: Identity and auth
- Sign in with Apple
- secure token validation and user identity mapping

### FR-4: Subscription entitlement
- StoreKit 2 purchase state
- RevenueCat webhook synchronization
- backend entitlement checks for paid features

### FR-5: Context integration (initial)
- Calendar-aware prompting via EventKit
- Focus-aware behavior boundaries

### FR-6: Backend service baseline
- FastAPI service with health/readiness endpoint
- research endpoint stub with entitlement gating

### FR-7: Transparent model routing
- stable NOBS request contract independent of model provider
- on-device, Tank, and optional NOBScloud routes
- visible route, fallback reason, and privacy receipt

### FR-8: Siri and system actions
- App Intents and App Schema adoption for supported NOBS actions
- deterministic confirmation, offline, and error behavior
- automated validation with AppIntentsTesting where available

### FR-9: Agent evaluation and safety
- evaluation cases for privacy, structured output, routing, unsupported-feature honesty, and injection resistance
- explicit tool permissions and sensitive-data boundaries
- observable failures without personal-data logging

### FR-10: Research retrieval baseline
- locally index safe Research Library metadata
- source-backed mock research entry and deep link
- sensitive fields excluded from system indexing by default

---

## 8. Non-Functional Requirements

### Security & privacy
- minimal data collection
- explicit consent for sensitive integrations
- no secret material in repository

### Reliability
- deterministic auth and entitlement behavior
- explicit logging for failure modes
- dependency health checks

### Performance
- responsive chat interactions
- bounded latency for local inference path

### Maintainability
- phase-gated implementation
- clear docs and operational runbooks

---

## 9. System Architecture (Initial)

The architecture is a policy-controlled router rather than a fixed client-to-cloud pipeline:

```text
iPhone chat / Siri / widgets / Live Activities
                    │
          NOBS intent + privacy policy
                    │
      ┌─────────────┼──────────────┐
      │             │              │
Apple local      Tank/NOBSbox   Optional cloud
Foundation       portable       PCC or NOBScloud
Models/Core AI   providers      provider
```

Foundation Models is the preferred Apple-side adapter. The shared NOBS request and response contracts remain platform-neutral for Windows/WSL2 Tank and future NOBSbox implementations.

Key integration services:
- Sign in with Apple
- StoreKit 2
- RevenueCat
- Cloudflare Tunnel (external access)

---

## 10. Roadmap

### Phase 1 — Launch/MVP
- Foundation Models routing spike
- App Schemas, App Intents, and AppIntentsTesting
- Core AI feasibility spike
- Evaluations and agent-security baseline
- CloudKit memory sync
- EventKit/HealthKit base context
- StoreKit 2 + entitlement pipeline
- Focus Filters
- Core Spotlight Research Library metadata
- Live Activities and WidgetKit briefing surfaces

### Phase 2 — Growth
- HomeKit
- Home Assistant/Tank translation layer
- Now Playing remote media sessions
- MusicKit and optional Music Understanding
- DeviceActivity
- WatchKit

### Phase 3 — Full Vision
- deeper private cloud escalation model
- macOS agent
- visionOS pathway
- Create ML personalization
- full continuity features

---

## 11. Success Metrics

### Product metrics
- daily active conversations per user
- proactive suggestion interaction rate
- retained users at 7/30/90 days

### Trust metrics
- user understanding of data usage (survey/UX signal)
- permission opt-in rates by integration
- support complaints related to privacy expectations

### Commercial metrics
- free-to-paid conversion
- paid retention/churn
- entitlement support incident rate

---

## 12. Risks and Mitigations

1. **WSL2 ↔ host inference bridge instability**
   - Mitigation: early fail-fast validation; halt downstream phases on failure.

2. **Permission fatigue and notification overload**
   - Mitigation: progressive consent, high-signal prompting policy.

3. **Entitlement mismatch across systems**
   - Mitigation: idempotent webhook handling + clear source-of-truth rules.

4. **Scope sprawl across ecosystem ambitions**
   - Mitigation: strict phase gates and out-of-scope enforcement.

5. **Siri AI feature overlap**
   - Mitigation: use Siri as a distribution surface; protect NOBS differentiation in cross-platform home unification, user-owned compute, sourced research, and transparent routing.

6. **Beta framework and model behavior changes**
   - Mitigation: isolate Apple adapters, maintain portable contracts, and rerun prompt/evaluation suites against every major beta and final release.

---

## 13. Out of Scope (Current Delivery Window)

- fully implemented research-routing intelligence
- production iOS app feature-complete build
- overnight autonomous coding-agent deployment
- complete smart-home orchestration layer

---

## 14. Release Readiness Criteria (MVP)

Before MVP release candidate:
- auth flow stable
- entitlement checks stable
- webhook lifecycle verified
- local inference bridge validated
- operational service runbook complete
- user-facing privacy explanation copy reviewed

---

## 15. Open Questions

1. Which Foundation Models dynamic profiles and provider hooks are available under production entitlements?
2. Which NOBS actions map cleanly to Apple App Schema domains?
3. What Research Library metadata is safe and useful to expose through Core Spotlight?
4. Which media services can be represented through remote Now Playing sessions without misleading ownership or playback state?
