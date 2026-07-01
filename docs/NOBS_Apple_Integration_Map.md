# NOBS Apple Integration Map

A phased framework integration plan for delivering NOBS as an Apple-native, privacy-first assistant.

---

## Strategic Goal

Build NOBS so the assistant feels like a natural extension of the Apple ecosystem rather than a separate destination app.

Primary design constraints:
- Privacy-first by default
- Local-first inference where possible
- Conversational interface over settings-heavy UX
- Progressive capability unlocks by context and subscription

---

## Phase 1 — Launch / MVP

**Objective:** Deliver a useful daily assistant loop with local intelligence, actionability, and subscription gating.

### 1) Foundation Models
**Purpose:** Free-tier local inference and private baseline intelligence.

Use cases:
- In-chat summarization
- Personal planning prompts
- Lightweight contextual reasoning

Acceptance criteria:
- Local model path available offline
- Sensitive context does not require cloud roundtrip
- Clear fallback behavior when model unavailable

### 2) App Intents
**Purpose:** Expose NOBS actions to Siri and system surfaces.

Use cases:
- “Ask NOBS to prep my day”
- “Ask NOBS to capture this reminder”

Acceptance criteria:
- Core intents registered and discoverable
- Intents resolve quickly and return user-safe messages

### 3) Shortcuts
**Purpose:** Enable automation workflows and user customization.

Use cases:
- Trigger workflows by time, focus mode, or location
- Let NOBS compose and run user-approved shortcuts

Acceptance criteria:
- Core NOBS intents callable in Shortcuts app
- Permission and confirmation boundaries documented

### 4) CloudKit
**Purpose:** Sync lightweight user memory and preferences via iCloud.

Use cases:
- Conversation state continuity
- Preference sync across user devices

Acceptance criteria:
- Sync conflict strategy defined
- No third-party cloud dependency required for base memory sync

### 5) EventKit + HealthKit
**Purpose:** Context signals for proactive assistance.

Use cases:
- Calendar-aware prep and reminders
- Optional wellness-aware suggestions

Acceptance criteria:
- Granular user permission handling
- Clearly explainable use of each signal

### 6) StoreKit 2
**Purpose:** Native subscription purchase and entitlement flow.

Use cases:
- Unlock NOBScloud features
- Manage plans and restore purchases

Acceptance criteria:
- Entitlement checks integrated with backend auth
- Clear UX for free vs paid capabilities

### 7) Focus Filters
**Purpose:** Adaptive behavior based on user mode.

Use cases:
- Work mode: concise, task-forward prompts
- Personal mode: broader reflective insights

Acceptance criteria:
- Behavior policies per focus context defined
- No notification spam in restrictive focus states

---

## Phase 2 — Growth

**Objective:** Expand NOBS from personal assistant to ambient ecosystem intelligence.

### HomeKit
- Contextual home automations
- Occupancy/routine-aware suggestions

### WidgetKit
- At-a-glance daily intelligence cards
- Priority actions surfaced without opening app

### Live Activities
- Session and workflow progress visibility
- Time-bound proactive updates

### DeviceActivity (Screen Time)
- Habit and pattern insights
- Gentle intervention suggestions

### CoreLocation (expanded)
- Better away/home transitions
- Geofenced routine assistance

### WatchKit
- Quick-capture and glance interactions
- Compact assistant prompts from watch context

---

## Phase 3 — Full Vision

**Objective:** Multi-device continuity and deeper personalization.

### Private Cloud Compute alignment
- Privacy-preserving cloud escalation path
- Cryptographic assurance model parity goals

### macOS agent
- Desktop-first work orchestration
- Local automation and productivity loops

### visionOS
- Spatial assistive overlays for planning and focus

### Create ML personalization
- User-specific behavior adaptation
- On-device personalization where feasible

### Cross-device continuity
- Handoff
- Universal Clipboard
- SharePlay
- MultipeerConnectivity
- AirDrop-assisted flows

---

## Sleeper Integrations (High Leverage)

### Action Button
A low-friction, high-frequency entry point for immediate NOBS capture and invocation.

### StandBy Mode
Persistent ambient dashboard opportunity while charging.

### DeviceActivity
Unique, difficult-to-copy personal habit insight layer.

### iOS Control Center
One-swipe accessibility can materially increase daily usage.

---

## Differentiator to Protect

**App Intents + Shortcuts + local context intelligence**

This combination is the moat: NOBS should feel like the operating system got smarter, not like users installed yet another chatbot.

---

## Implementation Notes

- Request permissions progressively and contextually
- Keep explanation and consent UX human-readable
- Maintain deterministic fallback when private/local signals are absent
- Avoid heavy cloud dependence for core free-tier behavior

---

## Dependencies and Risks

- API and framework evolution across iOS releases
- Permission denial rates for context-sensitive features
- Complexity of balancing proactive value with notification fatigue
- Subscription entitlement coherence across device/backend states

---

## Delivery Artifact Relationship

This file defines **Apple framework integration strategy**.

For build sequencing and backend implementation details, see:
- [`docs/NOBS_TANK_BUILD.md`](NOBS_TANK_BUILD.md)
- [`docs/PRD.md`](PRD.md)
