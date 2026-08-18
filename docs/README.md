# NOBS documentation index

Thirty-four documents live here. This page groups them so you can find the one
you need without opening ten files.

**New to the project?** Read these three, in order:

1. [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) — approved product truth. When
   anything else disagrees with this, this wins.
2. [`CURRENT_STATE.md`](CURRENT_STATE.md) — what is actually built versus planned.
3. [`CODEBASE_REFERENCE.md`](CODEBASE_REFERENCE.md) — module map, data flow,
   API surface, and settings.

Then read [`AI_WORKFLOW.md`](AI_WORKFLOW.md) before your first change: it is the
collaboration guide every contributor and coding agent follows.

## Product and direction

| Document | What it covers |
|---|---|
| [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) | Approved product truth — the source of truth for scope debates |
| [`PRD.md`](PRD.md) | Product requirements |
| [`CURRENT_STATE.md`](CURRENT_STATE.md) | Implemented-versus-planned boundary |
| [`ISSUE_BACKLOG.md`](ISSUE_BACKLOG.md) | Seed backlog of known work |
| [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md) | How the project takes money without paywalling the free core |
| [`SUPPORT_AND_PAYMENTS.md`](SUPPORT_AND_PAYMENTS.md) | Tips, sponsorship, and payment plumbing |
| [`CAREER_AND_VISIBILITY.md`](CAREER_AND_VISIBILITY.md) | Build-in-public and job-market plan |

## Working on the code

| Document | What it covers |
|---|---|
| [`AI_WORKFLOW.md`](AI_WORKFLOW.md) | Collaboration guide, git protocol, validation, definition of done |
| [`CODEBASE_REFERENCE.md`](CODEBASE_REFERENCE.md) | Module map, data flow, API surface, settings |
| [`AXIOM_AGENTS.md`](AXIOM_AGENTS.md) | Axiom skills for Apple-platform audits |
| [`SIMPLIFICATION_RESEARCH.md`](SIMPLIFICATION_RESEARCH.md) | Prior art, and where to stop hand-rolling |
| [`CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md) | When CI fails and it is not your diff |
| [`research/`](research/) | Stack research database — every tool, why it is here, and what to use instead |

## Tank backend and agent

| Document | What it covers |
|---|---|
| [`NOBS_TANK_BUILD.md`](NOBS_TANK_BUILD.md) | Tank API, Ollama, auth, deployment |
| [`TANK_AGENT_CORE.md`](TANK_AGENT_CORE.md) | Agent loop, tools, approvals, autonomy rules |
| [`TANK_DASHBOARD.md`](TANK_DASHBOARD.md) | Connected-screen dashboard and kiosk |
| [`TANK_FRESH_START.md`](TANK_FRESH_START.md) | Resetting a Tank to a clean state |
| [`TOOL_EXPANSION.md`](TOOL_EXPANSION.md) | Research on extending the tool and skill surface |
| [`NOBSDASH_DEPLOYMENT.md`](NOBSDASH_DEPLOYMENT.md) | Deploying the public website |
| [`mac_local_inference_setup.md`](mac_local_inference_setup.md) | Running local inference on a Mac at ~$0 |

## Apple platform

| Document | What it covers |
|---|---|
| [`IOS_SESSION_HANDOFF.md`](IOS_SESSION_HANDOFF.md) | Read before iPhone work |
| [`NOBS_Apple_Integration_Map.md`](NOBS_Apple_Integration_Map.md) | Which Apple frameworks NOBS touches and why |
| [`TIER1_APPLE_SLICE_SPEC.md`](TIER1_APPLE_SLICE_SPEC.md) | Tier 1 Apple slice implementation spec |
| [`BRIEFING_SLICE_SPEC.md`](BRIEFING_SLICE_SPEC.md) | Daily briefing implementation spec |
| [`APPLE_PLATFORM_BRAINSTORM.md`](APPLE_PLATFORM_BRAINSTORM.md) | Ranked platform opportunities |
| [`WWDC26_IMPACT.md`](WWDC26_IMPACT.md) | What WWDC26 changes for NOBS |
| [`PCC_INTEGRATION.md`](PCC_INTEGRATION.md) | Private Cloud Compute integration |
| [`PCC_ENTITLEMENT_CHECKLIST.md`](PCC_ENTITLEMENT_CHECKLIST.md) | Private Cloud Compute entitlements |
| [`DEVICE_HUB_QA.md`](DEVICE_HUB_QA.md) | Device support matrix and QA |
| [`EXTERNAL_CONFIG_SYNC.md`](EXTERNAL_CONFIG_SYNC.md) | iCloud config folder sync |

## Smart home

| Document | What it covers |
|---|---|
| [`GOOGLE_HOME_INTEGRATION.md`](GOOGLE_HOME_INTEGRATION.md) | Google Home architecture and learning path |

## Shipping

| Document | What it covers |
|---|---|
| [`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md) | TestFlight and public beta checklist |
| [`APP_STORE_IAP_SETUP.md`](APP_STORE_IAP_SETUP.md) | In-app purchase setup |
| [`PUBLIC_RELEASE.md`](PUBLIC_RELEASE.md) | Checklist before making the repository public |
| [`CODEX_APPLE_ACCOUNT_AUDIT_PROMPT.md`](CODEX_APPLE_ACCOUNT_AUDIT_PROMPT.md) | Prompt for auditing the Apple Developer account |

## Maintainer-only

[`internal/`](internal/) and [`app-store/`](app-store/) hold pointers to
maintainer-only material kept in the private repository.
