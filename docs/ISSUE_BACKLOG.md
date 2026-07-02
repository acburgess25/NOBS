# NOBS Initial Issue Backlog (Seed)

This backlog is organized into epics and implementation-ready tasks with concise acceptance criteria.

---

## Recommended Labels

- `epic`
- `backend`
- `ios`
- `auth`
- `billing`
- `infra`
- `docs`
- `security`
- `privacy`
- `research`
- `media`
- `qa`
- `accessibility`
- `product`
- `mvp`
- `phase-1`
- `phase-2`
- `phase-3`

---

## Epic 1 — Backend Foundation (NOBScloud)

### 1. [EPIC] Backend skeleton and configuration baseline
**Labels:** epic, backend, mvp, phase-1

Acceptance criteria:
- Python project scaffold exists with documented run path
- config loader implemented with required env validation
- `.env.example` added and accurate

### 2. Initialize SQLite schema for users and subscriptions
**Labels:** backend, mvp, phase-1

Acceptance criteria:
- DB initialization is idempotent
- users/subscriptions tables created
- local reset flow documented

### 3. Implement FastAPI app factory and `/health` endpoint
**Labels:** backend, mvp, phase-1

Acceptance criteria:
- app starts successfully in local dev
- `/health` returns status + timestamp
- dependency status included in payload

### 4. Add structured logging and error middleware
**Labels:** backend, infra, mvp, phase-1

Acceptance criteria:
- request IDs or correlation IDs available
- error responses are consistent JSON
- critical dependency failures log clearly

---

## Epic 2 — Local Inference Bridge

### 5. [EPIC] WSL2-to-Windows Ollama connectivity
**Labels:** epic, backend, infra, mvp, phase-1

Acceptance criteria:
- connectivity assumptions documented
- connectivity probe available
- known failure signatures documented

### 6. Build Ollama client module with timeout/retry policy
**Labels:** backend, infra, mvp, phase-1

Acceptance criteria:
- model invoke function implemented
- timeouts are explicit/configurable
- retries bounded and logged

### 7. Add startup probe for required Ollama model availability
**Labels:** backend, infra, mvp, phase-1

Acceptance criteria:
- startup fails loudly when required model missing
- clear remediation instructions included in logs

---

## Epic 3 — Identity & Authorization

### 8. [EPIC] Sign in with Apple verification pipeline
**Labels:** epic, auth, backend, mvp, phase-1

Acceptance criteria:
- JWT verification implemented
- `sub` claim persisted as user identity key
- invalid token scenarios covered

### 9. Create `/auth/apple` endpoint and user upsert logic
**Labels:** auth, backend, mvp, phase-1

Acceptance criteria:
- valid token creates/links user
- response returns stable auth/session payload contract

### 10. Add protected route dependency and unauthorized handling
**Labels:** auth, backend, security, mvp, phase-1

Acceptance criteria:
- protected routes reject invalid/missing auth
- unauthorized responses use consistent schema

---

## Epic 4 — Billing & Entitlements

### 11. [EPIC] StoreKit/RevenueCat entitlement coherence
**Labels:** epic, billing, backend, mvp, phase-1

Acceptance criteria:
- entitlement source-of-truth documented
- backend check path deterministic

### 12. Implement `subscriptions_active` check dependency
**Labels:** billing, backend, mvp, phase-1

Acceptance criteria:
- protected paid route blocked when inactive
- route proceeds when active

### 13. Create RevenueCat webhook endpoint
**Labels:** billing, backend, phase-1

Acceptance criteria:
- webhook endpoint accepts expected events
- payload validation and basic authenticity checks included

### 14. Process `EXPIRATION` and `CANCELLATION` events idempotently
**Labels:** billing, backend, phase-1

Acceptance criteria:
- repeated webhook events do not corrupt state
- subscription state transitions logged

### 15. Map RevenueCat `app_user_id` to Apple `sub`
**Labels:** billing, auth, backend, phase-1

Acceptance criteria:
- identity mapping strategy implemented and documented
- unknown app_user_id path handled safely

---

## Epic 5 — API Surface and Stubs

### 16. Add `/research` endpoint stub with entitlement gating
**Labels:** backend, mvp, phase-1

Acceptance criteria:
- endpoint exists and is authenticated
- inactive subscription returns clear denied reason
- active subscription returns stubbed response contract

### 17. Define API response contracts and error schema docs
**Labels:** backend, docs, phase-1

Acceptance criteria:
- endpoint contracts documented in repo
- common error payload shape defined

---

## Epic 6 — Operations & Deployment

### 18. [EPIC] Run backend as service in WSL2 (systemd)
**Labels:** epic, infra, backend, phase-1

Acceptance criteria:
- service file exists and is validated
- start/stop/status flows documented

### 19. Add operational runbook for work-mode / gaming-mode
**Labels:** docs, infra, phase-1

Acceptance criteria:
- clear process for reclaiming resources
- restart/recovery procedure documented

### 20. Configure Cloudflare Tunnel for secure external access
**Labels:** infra, security, phase-1

Acceptance criteria:
- tunnel configured only after local checks pass
- `/health` reachable externally without unsafe port exposure

---

## Epic 7 — iOS MVP Shell (Planning + Initial Build)

### 21. [EPIC] iOS chat shell and session baseline
**Labels:** epic, ios, mvp, phase-1

Acceptance criteria:
- chat UI shell exists with message list/input
- backend connectivity stub integrated

### 22. Integrate Sign in with Apple on iOS client
**Labels:** ios, auth, mvp, phase-1

Acceptance criteria:
- user can sign in
- token handoff to backend works

### 23. Integrate StoreKit 2 purchase and restore flows
**Labels:** ios, billing, mvp, phase-1

Acceptance criteria:
- purchase flow completes in sandbox
- restore flow updates entitlement UI state

### 24. Add EventKit permission flow and basic context ingestion
**Labels:** ios, mvp, phase-1

Acceptance criteria:
- permission request is contextual and explainable
- minimal calendar signal available for assistant logic

---

## Epic 8 — Product Safety, Trust, and Docs

### 25. [EPIC] Privacy and data-handling transparency docs
**Labels:** epic, docs, security, mvp, phase-1

Acceptance criteria:
- clear plain-language privacy summary available
- data storage and data flow described by tier

### 26. Create onboarding copy for permissions and expectations
**Labels:** docs, ios, mvp, phase-1

Acceptance criteria:
- copy explains why each permission is requested
- fallback behavior explained for denied permissions

### 27. Add architecture diagram(s) for local vs cloud paths
**Labels:** docs, backend, ios, phase-1

Acceptance criteria:
- diagrams checked into repo
- docs reference diagrams from README/PRD

### 28. Define MVP release checklist and go/no-go criteria
**Labels:** docs, mvp, phase-1

Acceptance criteria:
- release checklist file exists
- each criterion is measurable

---

## Suggested First Sprint (Top Priority)

1. Issue 29 (Foundation Models routing spike)
2. Issue 30 (App Schema and intent inventory)
3. Issue 31 (evaluation harness)
4. Issue 32 (agent-security threat model)
5. Issue 1 (backend skeleton)
6. Issue 3 (`/health`)
7. Issue 6 (Ollama client)

---

## Epic 9 — WWDC26 Architecture Adoption

### 29. Prototype Foundation Models routing
**Labels:** ios, backend, security, mvp, phase-1

Acceptance criteria:
- stable NOBS request/response contract defined
- on-device and mock Tank/provider routes demonstrated
- route and privacy metadata visible
- portable contract contains no Apple-only types

### 30. Inventory NOBS App Schemas and App Intents
**Labels:** ios, docs, mvp, phase-1

Acceptance criteria:
- MVP actions mapped to schema domains or custom intents
- confirmation and sensitive-input behavior documented
- unsupported actions return honest fallback copy
- validation plan uses AppIntentsTesting

### 31. Establish NOBS evaluation harness
**Labels:** ios, backend, security, mvp, phase-1

Acceptance criteria:
- privacy routing, structured output, unsupported-feature honesty, and injection cases included
- deterministic fixtures run locally and in CI
- model/provider changes produce comparable results

### 32. Threat-model agentic NOBS features
**Labels:** security, backend, ios, mvp, phase-1

Acceptance criteria:
- tool, research-ingestion, App Intent, and generated-skill boundaries reviewed
- data-flow and trust-boundary diagram created
- required mitigations become testable backlog items

### 33. Test a specialized model with Core AI
**Labels:** ios, security, phase-1

Acceptance criteria:
- representative model imported and invoked
- supported hardware, memory, latency, and energy measured
- fallback behavior documented

### 34. Prototype Research Library indexing with Core Spotlight
**Labels:** ios, research, privacy, phase-1

Acceptance criteria:
- safe mock topic indexed with source count and updated date
- Spotlight result deep-links into NOBS
- sensitive content remains excluded by default
- deletion removes the index entry

### 35. Prototype remote media with Now Playing
**Labels:** ios, media, phase-2

Acceptance criteria:
- mock Tank playback appears on supported system surfaces
- play/pause state stays synchronized
- unavailable or unsupported playback is represented honestly

### 36. Create Device Hub QA matrix
**Labels:** ios, qa, accessibility, phase-1

Acceptance criteria:
- representative iPhone sizes build and launch
- Dynamic Type, contrast, reduced motion, offline, and permission states listed
- screenshot capture is repeatable
- physical-device-only capabilities identified

### 37. Document Siri AI and NOBS ownership boundaries
**Labels:** product, ios, docs, phase-1

Acceptance criteria:
- generic Siri capability is not duplicated without added value
- explicit Siri-to-NOBS handoff cases defined
- NOBS differentiators and user-facing explanation documented

### 38. Add WWDC26 final-release audit
**Labels:** docs, qa, ios, phase-1

Acceptance criteria:
- beta assumptions rechecked against final SDKs
- prompts and evaluations rerun against the final Apple model
- entitlement and regional availability changes documented

---

## Notes

- Keep one PR per issue whenever practical.
- Keep acceptance criteria testable and binary.
- Link each implementation PR back to one parent epic.
