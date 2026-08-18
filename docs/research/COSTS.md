# What costs money, and what does not

The project's stance is that everything needed to **develop, test, and run**
NOBS should cost nothing. That is true today. This page records what is free,
what is genuinely paid, and what to do if you want to keep it at zero.

Last verified: August 18, 2026.

## Free — and staying free

| Thing | Why it costs nothing |
|---|---|
| **GitHub repository** | Public repos are free, including issues, wiki, discussions, and Pages. |
| **GitHub Actions** | Free and **unlimited** on standard hosted runners for public repositories. Verified: the Linux/macOS/Windows matrix ran green and free on August 14, 2026. |
| **Self-hosted runners** | The Mac and the Tank are hardware you already own. Actions never bills for a self-hosted runner, on any repo. |
| **Ollama and every local model** | Open weights, run on your own hardware. `qwen3:8b`, `qwen2.5-coder:14b`, `nomic-embed-text` — no API keys, no per-token cost. |
| **The whole Python backend** | FastAPI, Uvicorn, Pydantic, HTTPX, SQLite, pytest, Ruff — all open source. |
| **Search, weather, news, Wikipedia tools** | `ddgs`, Open-Meteo, RSS, and the Wikipedia API need no account or key. This is deliberate: the free local core must not depend on a paid service. |
| **The website toolchain** | React, Vite, pnpm, Phosphor icons. |
| **Home Assistant** | Open source, self-hosted. |
| **cloudflared tunnel** | Free tier covers publishing one site with no open inbound ports. |
| **Xcode and the iOS Simulator** | Free with an Apple ID. You can build, run, and test the app on the Simulator without paying anything. |

## Genuinely paid

| Thing | Cost | What it buys | Needed for |
|---|---|---|---|
| **Apple Developer Program** | $99/year | Code signing for real devices, TestFlight, App Store distribution, and the entitlements the app declares | Shipping the iPhone app to anyone, including yourself on a physical phone for more than 7 days |
| **`nobsdash.com` domain** | ~$10–15/year | The public domain | The public site. GitHub Pages would serve it free at `*.github.io` instead. |

Nothing else in this repository requires a payment method.

### About the Apple Developer Program

This is the only cost that gates real product progress, and there is no way
around it — Apple requires it for TestFlight and the App Store. Everything
short of distribution works without it:

- the Simulator build (`scripts/build-ios-simulator.sh`),
- the iOS test suite (`scripts/test-ios.sh`),
- free provisioning to your own device for 7-day builds,
- the entire Tank backend and dashboard.

`.github/workflows/testflight.yml` and the eleven `scripts/ci-*` signing
scripts exist only to serve it. They are kept because they represent real work
and will be needed the moment you enroll — they simply do not run until then.
If you decide not to enroll, nothing else in the project breaks.

### About payments *in* (not out)

Square, Stripe, and StoreKit appear in the codebase to **receive** support, not
to spend. They take a percentage of what comes in and cost nothing to have
configured. See [`../SUPPORT_AND_PAYMENTS.md`](../SUPPORT_AND_PAYMENTS.md).

## If CI goes red without a code change

A hosted-runner job that fails in seconds with `runner_id: 0` and no logs is an
account-level Actions hold, **not** a charge for this repository — public repo
Actions is free. See
[`../CI_TROUBLESHOOTING.md`](../CI_TROUBLESHOOTING.md#every-hosted-job-fails-in-seconds-august-2026).

Backend CI is arranged so this cannot block you: the gating check runs on the
self-hosted Mac, and the hosted cross-platform matrix is `continue-on-error`.

## Rule for anything new

Before adding a service or dependency, check it against the `constraints` list
in [`stack.json`](stack.json). In cost terms:

1. Prefer something that runs locally on hardware already owned.
2. A free tier that requires a credit card on file is not free — treat it as paid.
3. Anything metered per request or per token does not belong in the free local
   core. `PRODUCT_DECISIONS.md` §21 lists what must stay free forever.
4. If a paid service is genuinely the right answer, it belongs behind the
   optional NOBScloud boundary, never in the default path.
