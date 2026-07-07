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

WWDC26 changes the implementation order. See [`WWDC26_IMPACT.md`](WWDC26_IMPACT.md) for sources and architectural decisions.

---

## Phase 1 — Launch / MVP

**Objective:** Deliver a useful daily assistant loop with local intelligence, actionability, and subscription gating.

### 1) Foundation Models routing layer
**Purpose:** Free-tier local inference plus a common Apple-side adapter for local, Private Cloud Compute, Core AI, Tank, and server-provider routes.

Use cases:
- In-chat summarization
- Personal planning prompts
- Lightweight contextual reasoning

Acceptance criteria:
- Local model path available offline
- Sensitive context does not require cloud roundtrip
- Clear fallback behavior when model unavailable
- Route, reason, data categories, and privacy receipt are observable
- Shared request contract remains portable to Windows/WSL2 Tank

### 2) App Schemas + App Intents
**Purpose:** Expose NOBS actions to Siri and system surfaces.

Use cases:
- “Ask NOBS to prep my day”
- “Ask NOBS to capture this reminder”

Acceptance criteria:
- Core intents registered and discoverable
- Intents resolve quickly and return user-safe messages
- Confirmation, offline, and sensitive-input behavior defined
- Adoption validated with AppIntentsTesting

### 3) Core AI feasibility
**Purpose:** Evaluate specialized local models that improve privacy, latency, or offline capability.

Acceptance criteria:
- one representative model imported and profiled
- supported-device and memory constraints documented
- fallback path tested

### 4) Evaluations + agent security
**Purpose:** Make privacy, honesty, routing, and tool safety release gates.

Acceptance criteria:
- deterministic evaluation fixtures checked into the repo
- prompt-injection and sensitive-data cases covered
- model/provider changes cannot ship without evaluation results

### 5) Shortcuts
**Purpose:** Enable automation workflows and user customization.

Use cases:
- Trigger workflows by time, focus mode, or location
- Let NOBS compose and run user-approved shortcuts

Acceptance criteria:
- Core NOBS intents callable in Shortcuts app
- Permission and confirmation boundaries documented

### 6) Core Spotlight
**Purpose:** Search safe Research Library summaries and deep-link into NOBS.

Acceptance criteria:
- mock sourced topic is searchable locally
- protected source contents are excluded by default
- delete and reindex behavior verified

### 7) CloudKit
**Purpose:** Sync lightweight user memory and preferences via iCloud.

Use cases:
- Conversation state continuity
- Preference sync across user devices

Acceptance criteria:
- Sync conflict strategy defined
- No third-party cloud dependency required for base memory sync

### 8) EventKit + HealthKit
**Purpose:** Context signals for proactive assistance.

Use cases:
- Calendar-aware prep and reminders
- Optional wellness-aware suggestions

Acceptance criteria:
- Granular user permission handling
- Clearly explainable use of each signal

### 9) WidgetKit + Live Activities
**Purpose:** Surface briefings and active workflows without turning notifications into another inbox.

Acceptance criteria:
- useful locked and unlocked states
- privacy-safe redaction
- Dynamic Type and reduced-motion verification

### 10) StoreKit 2
**Purpose:** Native subscription purchase and entitlement flow.

Use cases:
- Unlock NOBScloud features
- Manage plans and restore purchases

Acceptance criteria:
- Entitlement checks integrated with backend auth
- Clear UX for free vs paid capabilities

### 11) Focus Filters
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
- Apple Home endpoint for the Tank/Home Assistant translation layer

### Now Playing + MusicKit
- Represent supported Tank or household playback through remote media sessions
- Continue music, podcasts, and briefings across Apple system surfaces
- Evaluate Music Understanding without covert mood profiling

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

**App Intents + user-owned compute + cross-platform home translation + sourced research**

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

For a ranked backlog focused on average-user value and per-user adaptation, see:
- [`docs/APPLE_PLATFORM_BRAINSTORM.md`](APPLE_PLATFORM_BRAINSTORM.md)

For Tier 1 implementation detail (onboarding, widgets, Siri, Focus, notifications), see:
- [`docs/TIER1_APPLE_SLICE_SPEC.md`](TIER1_APPLE_SLICE_SPEC.md)

For build sequencing and backend implementation details, see:
- [`docs/NOBS_TANK_BUILD.md`](NOBS_TANK_BUILD.md)
- [`docs/PRD.md`](PRD.md)
