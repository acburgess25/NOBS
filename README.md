<div align="center">

# NOBS

### Your technology. Finally working for you.

A local-first personal assistant that turns a chaotic day into a realistic plan—without turning your life into someone else's dataset.

[![Website](https://img.shields.io/badge/website-nobsdash.com-36584a?style=flat-square)](https://nobsdash.com)
[![Swift 6](https://img.shields.io/badge/Swift-6-f05138?style=flat-square&logo=swift&logoColor=white)](https://www.swift.org)
[![iOS 18+](https://img.shields.io/badge/iOS-18%2B-111111?style=flat-square&logo=apple)](https://developer.apple.com/ios/)
[![Backend CI](https://img.shields.io/github/actions/workflow/status/acburgess25/NOBS/backend-ci.yml?branch=main&style=flat-square&label=backend%20CI)](https://github.com/acburgess25/NOBS/actions/workflows/backend-ci.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-6d7f68?style=flat-square)](LICENSE)

[Explore the project](https://nobsdash.com) · [Sponsor the build](https://github.com/sponsors/acburgess25) · [See what works](#what-works-today) · [Contribute](CONTRIBUTING.md)

</div>

---

NOBS is a privacy-first assistant for iPhone, iPad, Mac, and a private **Tank** computer. Everyday intelligence stays on the user's devices whenever possible. Optional paid capacity (NOBScloud) is for convenience when Tank is away—not a paywall on the free local core.

> **Project status:** Active, early-stage prototype. Tips and sponsorships fund open development; they do not unlock features. In-app NOBScloud is App Store IAP once distribution is live. See [`docs/MONETIZATION_AND_GROWTH.md`](docs/MONETIZATION_AND_GROWTH.md).

## Support the free core

Optional support keeps the local-first build going:

1. **[GitHub Sponsors](https://github.com/sponsors/acburgess25)** — fastest path today (enable the listing if the link redirects to your profile).
2. **Stripe card tips** — add Payment Links to `website/public/support.json` (phone-friendly; no home Mac required). Helper: `scripts/setup_stripe_support_links.py`.
3. **In-app tips + NOBScloud** — StoreKit products in the app; needs App Store Connect Paid Apps + a TestFlight/App Store build.

Do not put morning briefing or local chat behind a paywall.

## What works today

This repository contains an early end-to-end prototype:

- **Apple app:** SwiftUI conversation-first experience, Today briefing, widgets, Siri/App Intents, visible processing labels, and privacy receipts.
- **Private Tank:** Authenticated FastAPI + Ollama backend with an approval-gated agent and Personal, Business, and Shared contexts.
- **Safe automation:** State-changing tools queue exact actions for explicit approval; decisions are atomic, audited, and non-replayable.
- **Cross-platform companions:** A macOS Tank supervisor and an Android tablet companion share documented, authenticated contracts.
- **Room-safe dashboard:** Live health, approvals, activity, and light/dark themes without exposing personal content.
- **Honest fallback:** The app remains useful locally when Tank is unavailable and labels unfinished capabilities clearly.

This is not a production release. Household identity, hosted NOBScloud servers, direct Google Home/Alexa integration, and most proactive automation remain planned. StoreKit tips/subscription UI and on-device NOBScloud→Apple Cloud fallback are in the app; distribution and ASC products still gate live purchases.

## Why NOBS

| Principle | What it means in practice |
|---|---|
| **Local first** | Useful core features run on the devices you already own. |
| **Privacy visible** | Every response identifies where it was processed. |
| **Approval before action** | The model may propose a change; it never authorizes one. |
| **No manufactured lock-in** | No intentional degradation, surveillance advertising, or forced hardware cycle. |
| **Built in public** | Product decisions, limitations, architecture, and progress stay inspectable. |

## Repository map

| Path | Purpose |
|---|---|
| `NOBS/` | SwiftUI application |
| `NOBSWidgets/` | Home Screen, Lock Screen, and Live Activity extensions |
| `NOBSTankMac/` | macOS menu-bar Tank supervisor |
| `NOBSAndroid/` | Native Android tablet companion |
| `app/` | FastAPI Tank API and Ollama bridge |
| `tests/` | Backend contract and failure-path tests |
| `deploy/tank/` | Tank service definitions |
| `design/` | Approved visual references |
| `docs/` | Product truth, architecture, research, and operating guides |
| `docs/internal/` | Pointer to maintainer-only docs in [NOBS-private](https://github.com/acburgess25/NOBS-private) |
| `website/` | Public project website |

## Architecture at a glance

```text
iPhone / iPad / Mac / Android
            │
            │ authenticated private-network API
            ▼
     Tank (FastAPI + Ollama)
            │
            ├── approval-gated tools
            ├── local memory and schedules
            └── room-safe dashboard
```

NOBS prefers on-device processing, uses Tank when the user has paired one, and exposes cloud routes only behind explicit policy and availability gates.

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

## NOBS local AI stack (low-cost mode)

Use the NOBS setup scripts to run AI workloads on your own hardware (Tank or local dev machine):

### macOS / Linux / WSL2

```bash
./scripts/setup-local-ai.sh
```

### Windows PowerShell

```powershell
.\scripts\setup-local-ai.ps1
```

This prepares:

- local Ollama models (`qwen3:8b`, `qwen2.5-coder:14b`);
- Aider for coding-agent workflows;
- Open WebUI in a dedicated user venv.

For Tank systemd deployment, use `deploy/tank/open-webui.service`.

## Run the Apple app

Open `NOBS.xcodeproj` in Xcode 27 or newer and run the `NOBS` scheme on an iOS 27 simulator or device. In the app's Privacy view, enter the Tank URL and the same device token configured on the server.

- Simulator default: `http://127.0.0.1:8000`
- Device default: `http://tank.local:8000`

The device must be able to reach Tank on the private network. Local HTTP is permitted for this prototype; production remote access must use a private tunnel and authenticated HTTPS rather than an exposed home port.

## Product and contributor truth

- [Canonical codebase reference](docs/CODEBASE_REFERENCE.md) — onboarding and architecture for humans and agents
- [Approved product decisions](docs/PRODUCT_DECISIONS.md)
- [Shared agent and contributor workflow](docs/AI_WORKFLOW.md)
- [Current implementation state and next handoff](docs/CURRENT_STATE.md)
- [Product requirements](docs/PRD.md)
- [Tank build and operations guide](docs/NOBS_TANK_BUILD.md)
- [Tank agent architecture and approval policy](docs/TANK_AGENT_CORE.md)
- [Tank connected-screen dashboard](docs/TANK_DASHBOARD.md)
- [Support, donations, and payments](docs/SUPPORT_AND_PAYMENTS.md)
- [Implementation backlog](docs/ISSUE_BACKLOG.md)

When documents disagree, `docs/PRODUCT_DECISIONS.md` is the product source of truth. Planned capabilities must not be presented as shipped.

## Collaboration and IP baseline

- Public collaboration codename: **Project Lantern**.
- This repository is licensed under **AGPL-3.0-or-later** (`LICENSE`).
- Contributions are accepted under `CONTRIBUTING.md` rules, including DCO sign-off (`git commit -s`).
- Report security issues per [`SECURITY.md`](SECURITY.md); do not file public issues for exploitable vulnerabilities.
- Before making the repository public, follow [`docs/PUBLIC_RELEASE.md`](docs/PUBLIC_RELEASE.md).
