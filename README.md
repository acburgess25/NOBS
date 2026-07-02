# NOBS

**Privacy-first local AI for regular people — built for the Apple ecosystem.**

NOBS is an Apple-native assistant platform designed to run on your hardware first, keep your personal context private, and provide a proactive, conversation-first experience that feels like iMessage with real intelligence.

## Why NOBS

Most assistants are cloud-first and opaque. NOBS is built around:

- **Local inference by default** (Apple Foundation Models for free tier)
- **Privacy-first architecture** (user context stays with the user)
- **Conversation-first UX** (the chat is the app)
- **Practical automation** across Apple frameworks and user context
- **Trust through transparency**

## Core Product Vision

NOBS positions itself as **“the Apple ecosystem made actually smart for regular users.”**

### UX principle: The Chat IS the App

No complex menus. No traditional settings pages. Configuration and personalization happen through natural conversation.

Planned implementation:
- Single iMessage-style chat interface (SwiftUI, ExyteChat planned)
- In-chat settings and adaptation
- Proactive messaging based on context and patterns

### Context-aware behavior tiers

NOBS adapts to location, power state, schedule, and server availability:

| State | Behavior |
|---|---|
| Away + on battery | Lightweight local mode, low resource use, high-signal prompts |
| Away + plugged in | More background prep for upcoming events |
| Home + on Wi‑Fi | Home-aware mode with more relaxed, ambient assistance |
| Home + plugged + tank online | Full-power mode, deep analysis and automation |

Primary context signals:
- CoreLocation
- EventKit
- Charging state
- Tank online/offline availability

## Monetization

### Free tier
- On-device inference with Apple Foundation Models
- Private, local-first experience

### Paid tier: NOBScloud
- Hosted LLM consultation path for heavier tasks
- Privacy-preserving architecture inspired by Apple Private Cloud Compute

Billing and auth stack:
- StoreKit 2 subscriptions
- Sign in with Apple
- RevenueCat webhook-based subscription state

## Architecture Snapshot

### Current backend direction (NOBScloud on Tank)
- FastAPI backend
- SQLite for initial state and subscription flags
- Ollama bridge for local model execution (WSL2 ↔ Windows host)
- Sign in with Apple JWT verification
- RevenueCat webhook ingestion
- Cloudflare Tunnel exposure only after local verification

### Explicit non-goals for current backend phase
- Final research routing logic implementation (stub only)
- iOS app implementation
- OpenHands 24/7 agent deployment
- HomeKit/smart-home integration implementation

## Apple Integration Roadmap

### Phase 1 (Launch / MVP)
Foundation Models → App Intents → Shortcuts → CloudKit → EventKit + HealthKit → StoreKit 2 → Focus Filters

### Phase 2 (Growth)
HomeKit → WidgetKit → Live Activities → DeviceActivity → CoreLocation → WatchKit

### Phase 3 (Full Vision)
Private Cloud Compute alignment → macOS agent → visionOS → Create ML personalization → full continuity features

See full details in:
- [`docs/NOBS_Apple_Integration_Map.md`](docs/NOBS_Apple_Integration_Map.md)

## Core Documents

- Approved product decisions: [`docs/PRODUCT_DECISIONS.md`](docs/PRODUCT_DECISIONS.md)
- Shared Codex / Claude Code / Antigravity workflow: [`docs/AI_WORKFLOW.md`](docs/AI_WORKFLOW.md)
- Product + architecture map: [`docs/PRD.md`](docs/PRD.md)
- Apple framework integration plan: [`docs/NOBS_Apple_Integration_Map.md`](docs/NOBS_Apple_Integration_Map.md)
- Backend phased build spec: [`docs/NOBS_TANK_BUILD.md`](docs/NOBS_TANK_BUILD.md)
- Initial issue backlog seed: [`docs/ISSUE_BACKLOG.md`](docs/ISSUE_BACKLOG.md)

## Cross-Platform Development Setup

NOBS uses one Python task runner on macOS, Windows, WSL2, and Linux.

### macOS, WSL2, or Linux

```bash
./scripts/setup.sh
python3 scripts/dev.py check
python3 scripts/dev.py run
```

### Windows PowerShell

```powershell
.\scripts\setup.ps1
py -3.11 scripts/dev.py check
py -3.11 scripts/dev.py run
```

Python 3.11 or newer is required. The iPhone app still requires macOS and Xcode; shared services and contracts must remain platform-neutral.

## Repo Status

This repository currently contains planning, architecture, and execution documentation. Code implementation is expected to proceed in phased delivery based on the specs above.

## Guiding Principle

**Meet users where they are.**
NOBS should work with existing hardware and real life constraints, not require users to become power users.
