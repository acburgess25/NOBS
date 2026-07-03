# NOBS

**Your technology. Finally working for you.**

NOBS is a local-first, privacy-first personal assistant for the Apple ecosystem. It is designed to reduce mental load while keeping everyday intelligence on the user's iPhone or private Tank hardware. Optional NOBScloud processing is a future capability, not a requirement.

## What works today

This repository contains an early end-to-end prototype:

- a SwiftUI iPhone/iPad app with conversational onboarding and chat at the center;
- an on-device Today view that reads Calendar data only after contextual permission;
- visible Local or Tank processing labels and per-response privacy receipts;
- secure Tank token storage in the iOS Keychain;
- an authenticated FastAPI chat endpoint backed by Ollama on Tank;
- honest local fallback when Tank is unavailable;
- placeholder views that clearly label unfinished Memory, Home, and automation capabilities;
- cross-platform backend setup and automated API tests.
- an approval-gated Tank agent core with separated Personal, Business, and Shared contexts.
- a room-safe Tank dashboard with live health, approvals, activity, and light/dark themes.

This is a prototype, not a production release. Memory, smart-home control, NOBScloud, account sync, subscriptions, and most proactive automation remain planned.

## Repository map

| Path | Purpose |
|---|---|
| `NOBS/` | SwiftUI application |
| `app/` | FastAPI Tank API and Ollama bridge |
| `tests/` | Backend contract and failure-path tests |
| `deploy/tank/` | Tank service definitions |
| `design/` | Approved visual references |
| `docs/` | Product truth, architecture, research, and operating guides |
| `website/` | Public project website |

## Run the backend

Python 3.11 or newer is required.

### macOS, Linux, or WSL2

```bash
./scripts/setup.sh
python3 scripts/dev.py check
cp .env.example .env
python3 scripts/dev.py run
```

### Windows PowerShell

```powershell
.\scripts\setup.ps1
py -3.11 scripts/dev.py check
Copy-Item .env.example .env
py -3.11 scripts/dev.py run
```

Set a strong `NOBS_DEVICE_TOKEN` in `.env` before using `/ready` or `/chat`. Ollama defaults to `http://127.0.0.1:11434` with `qwen3:8b`; both values are configurable. Never commit `.env`.

Useful commands:

```bash
python3 scripts/dev.py check  # tests and lint
python3 scripts/dev.py test
python3 scripts/dev.py lint
python3 scripts/dev.py run
```

## Run the Apple app

Open `NOBS.xcodeproj` in Xcode 27 or newer and run the `NOBS` scheme on an iOS 27 simulator or device. In the app's Privacy view, enter the Tank URL and the same device token configured on the server.

- Simulator default: `http://127.0.0.1:8000`
- Device default: `http://tank.local:8000`

The device must be able to reach Tank on the private network. Local HTTP is permitted for this prototype; production remote access must use a private tunnel and authenticated HTTPS rather than an exposed home port.

## Product and contributor truth

- [Approved product decisions](docs/PRODUCT_DECISIONS.md)
- [Shared agent and contributor workflow](docs/AI_WORKFLOW.md)
- [Current implementation state and next handoff](docs/CURRENT_STATE.md)
- [Product requirements](docs/PRD.md)
- [Tank build and operations guide](docs/NOBS_TANK_BUILD.md)
- [Tank agent architecture and approval policy](docs/TANK_AGENT_CORE.md)
- [Tank connected-screen dashboard](docs/TANK_DASHBOARD.md)
- [Implementation backlog](docs/ISSUE_BACKLOG.md)

When documents disagree, `docs/PRODUCT_DECISIONS.md` is the product source of truth. Planned capabilities must not be presented as shipped.
