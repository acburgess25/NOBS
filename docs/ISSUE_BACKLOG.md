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

1. Issue 1 (backend skeleton)
2. Issue 3 (`/health`)
3. Issue 6 (Ollama client)
4. Issue 8 (Apple token verification)
5. Issue 13 (RevenueCat webhook endpoint)
6. Issue 16 (`/research` gated stub)
7. Issue 18 (systemd service)

---

## Notes

- Keep one PR per issue whenever practical.
- Keep acceptance criteria testable and binary.
- Link each implementation PR back to one parent epic.
