# NOBS Product Requirements Document (PRD)

## 1. Executive Summary

NOBS is a privacy-first, local AI assistant platform for regular users in the Apple ecosystem. It provides a single conversation interface that becomes context-aware over time, performs useful proactive support, and preserves user trust by minimizing cloud dependence.

NOBS monetizes via a two-tier model:
- Free local-first tier (on-device inference)
- Paid NOBScloud tier (hosted consultation path for heavier tasks)

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

Client (iOS) ↔ NOBScloud backend (FastAPI) ↔ local model path (Ollama bridge) + subscription/auth services

Key integration services:
- Sign in with Apple
- StoreKit 2
- RevenueCat
- Cloudflare Tunnel (external access)

---

## 10. Roadmap

### Phase 1 — Launch/MVP
- Foundation Models
- App Intents + Shortcuts
- CloudKit memory sync
- EventKit/HealthKit base context
- StoreKit 2 + entitlement pipeline
- Focus Filters

### Phase 2 — Growth
- HomeKit
- WidgetKit
- Live Activities
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

1. Final NOBScloud research-routing policy and model arbitration
2. Timing and scope for autonomous overnight coding agent integration
3. Exact iOS implementation sequencing after backend baseline completion
