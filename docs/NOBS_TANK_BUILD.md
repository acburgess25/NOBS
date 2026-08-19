# NOBS Tank Build

Phased implementation plan for a safe, verifiable backend build on Tank.

---

## Build Objective

Deliver a production-minded private API on Tank with:
- authenticated device access;
- a verified local Ollama inference path;
- explicit failure behavior and privacy receipts;
- an operational systemd deployment path.

The plan prioritizes **fail-fast validation**, **traceability**, and **safe unattended execution**.

---

## Environment Model

### Host topology
- **Current host OS:** Ubuntu Linux on Tank
- **Backend runtime:** FastAPI on Tank
- **Public portfolio:** static origin on `127.0.0.1` through Cloudflare Tunnel
- **Historical note:** the original plan assumed Windows 11 with WSL2 and Ollama on the Windows host; implementation must follow the current Linux host while preserving cross-platform development support

### Operational model
- Tank is dedicated NOBS infrastructure, not a gaming machine.
- The API and Ollama run as local services.
- Logs must be explicit and actionable without recording conversation content or secrets.

## Current implementation status

Implemented in this repository:

- centralized environment configuration in `app/config.py`;
- deterministic public `GET /health`;
- device-token-protected `GET /ready` and `POST /chat`;
- bounded Ollama requests with safe connection, timeout, HTTP, malformed-response, and empty-response failures;
- Local/Tank processing labels and privacy receipts in the iOS client;
- a systemd user service template at `deploy/tank/nobs-api.service`;
- backend tests and lint through `python scripts/dev.py check`.
- a bounded Ollama tool loop with local audit history and approval-gated changes.

Still planned:

- persistent application data and migrations;
- per-device identity and token rotation;
- Sign in with Apple and household profiles;
- subscription/entitlement support for optional NOBScloud features;
- production-grade observability, backup, and remote access.

---

## Phase Plan

## Phase 1 — Project Skeleton

Create:
- `app/` package structure
- `requirements.txt` or `pyproject.toml`
- `.env.example`
- baseline `README.md` setup section

Acceptance criteria:
- project bootstraps locally
- linter/test hooks stubbed or documented
- secrets excluded from version control

---

## Phase 2 — Config + SQLite Database

Implement:
- centralized config loader
- SQLite initialization + migrations strategy (lightweight acceptable)
- user/subscription schema foundations

Suggested tables (minimum):
- `users` (id, apple_sub, created_at)
- `subscriptions` (user_id, active, updated_at, source)

Acceptance criteria:
- DB initializes idempotently
- config fails loudly for missing required vars

---

## Phase 3 — FastAPI App + `/health`

Implement:
- app factory or modular startup pattern
- health endpoint with dependency checks

Acceptance criteria:
- `GET /health` returns success payload locally
- health response includes timestamp + version/build marker

---

## Phase 4 — Local Model Bridge (implemented prototype)

Implement:
- local network bridge from the Tank API to the local model server
- authenticated readiness and runtime checks
- clear error handling for host resolution/network failures

The bridge lives in `app/inference.py` and speaks Ollama's `/api/chat` dialect internally.
`NOBS_INFERENCE_PROVIDER=lmstudio` translates the same requests to LM Studio's
OpenAI-compatible server instead — see [`LM_STUDIO_SETUP.md`](LM_STUDIO_SETUP.md). Add new
providers there, not at the call sites.

Acceptance criteria:
- backend can complete a test inference call via bridge
- failures are loud and explicit (no silent fallback)
- **STOP build if this phase fails**

Risk note:
- This is the highest-risk phase and blocks all downstream value.

---

## Phase 5 — Sign in with Apple JWT Verification

Implement:
- Apple identity token validation
- claim extraction (`sub`, issuer, audience, expiry validation)
- user upsert on valid auth

Acceptance criteria:
- invalid tokens rejected with clear status codes
- valid token path creates/links user identity

---

## Phase 6 — Auth Gating + Subscription Checks

Implement:
- auth middleware/dependencies
- entitlement checks for protected endpoints
- clear free vs paid path responses

Acceptance criteria:
- protected endpoints require valid auth
- subscription-required endpoint returns deterministic denied response when inactive

---

## Phase 7 — RevenueCat Webhooks

Implement:
- webhook endpoint for subscription lifecycle events
- verify event payload structure/signature as configured
- handle `EXPIRATION` and `CANCELLATION`
- map `app_user_id` to Apple `sub`

Acceptance criteria:
- webhook updates local subscription state correctly
- idempotent event processing (retries do not corrupt state)
- subscription toggles observable in logs and DB

---

## Phase 8 — Tank service mode

Implement:
- `systemd` service unit and docs
- operational commands (start/stop/status/logs)
- dedicated-service start, stop, restart, and log procedures

Acceptance criteria:
- service survives reboot or is clearly documented otherwise
- one-command status checks available

---

## Phase 9 — Cloudflare Tunnel (Last)

Implement only after all local checks pass:
- tunnel setup and secure ingress
- restricted origin exposure

Acceptance criteria:
- external `/health` reachable from non-home network
- no direct unsafe port exposure

---

## Explicitly Out of Scope (Current Backend Pass)

- final `/research` routing design (stub only)
- additional iOS product features beyond the current vertical slice
- OpenHands 24/7 coding agent setup
- HomeKit integration implementation

---

## Security and Reliability Rules

- `.env` contains secrets and is never committed
- `.env.example` includes keys with blank/sample values only
- log loudly on dependency or network failures
- avoid silently degraded modes for critical services
- include minimal operational runbook in repo docs

---

## Suggested Endpoint Set (Minimum)

- `GET /health`
- `POST /auth/apple`
- `POST /webhooks/revenuecat`
- `POST /research` (stub + entitlement gate)

---

## Verification Checklist by Phase

Each phase should include:
1. What changed
2. How to run validation
3. Expected output
4. Rollback notes (if needed)

Recommended commit discipline:
- one commit per phase
- concise commit messages with phase prefix

---

## Failure Handling Policy

If any critical dependency check fails:
1. stop progression to next phase
2. log root cause clearly
3. provide a remediation checklist
4. rerun validation before continuing

---

## Future Extensions (Post-Phase)

- replace SQLite with managed relational store if scale requires
- implement full research routing policy and model arbitration
- add metrics/observability (structured logs + tracing)
- add CI checks for schema, auth, and webhook contract validation
