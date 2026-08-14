# Landing page copy — "stop renting your AI"

**Status:** Draft. Copy only — no implementation. The site is a Vite/React app under `website/` and is built separately; this file is the words, not the markup.
**Covers:** the nobsdash.com landing page, aimed at (1) people paying $20/mo for ChatGPT who'd rather run AI on hardware they already own, and (2) developers who might contribute.
**Publish to:** `nobsdash.com` landing page. Reuse the hero + status table for the GitHub repo README and the X/LinkedIn pinned post.
**Honesty check:** every capability claim below was checked against `docs/CURRENT_STATE.md` on **August 14, 2026**, and the test count (`246` on `main`; a pending optimizer route-classification test makes it 247 when merged) against a live run the same day. Re-check both before publishing (see *Notes before publishing*).

**Accessibility rule for whoever implements this:** the three status markers are **text labels**, not colors. "✅ Works today", "🧪 Built, being verified", "🔜 Coming soon" must each render as readable text next to the item — a colored dot alone is not acceptable. Colors and emoji are decoration on top of the words, never the only signal.

---

## 1. Hero

### Headline options

1. **Stop renting your AI.**
   *(Shortest, angriest, most quotable. My pick for the live site.)*

2. **Your computer was already smart enough.**
   *(Leads with the hardware-you-own idea instead of the subscription. Warmer, less confrontational.)*

3. **A personal AI that runs on your hardware, not someone else's business model.**
   *(Most explicit. Best if the page has to explain itself in one line — e.g. a link preview or a README.)*

### Subhead (pairs with any of the three)

> NOBS is a private, local-first assistant. It runs on a gaming PC or a Mac you already own — no ads, no tracking, no subscription required for the core. Open source. Built in public by one person.

### Tagline (brand constant, use as a kicker or footer line)

> **Your technology. Finally working for you.**

### Primary CTA

> **See the code → github.com/acburgess25/NOBS**
> Everything below is in that repo. So is everything that doesn't work yet.

### Secondary CTAs

> **Follow the build** — devlogs, honest status, no launch theater.
> **Buy me a coffee** — one-time tip, entirely optional. NOBS is free and stays free.

*(Implementation note: the tip link lives in `website/public/support.json` → `donateOneTime`. Do **not** add a GitHub Sponsors CTA — the account isn't enrolled, and `support.json` / `.github/FUNDING.yml` both deliberately leave it empty. The recurring Square link is still a placeholder; don't surface it until it's filled in.)*

---

## 2. The problem

**Section heading:** *The math stopped making sense.*

> ChatGPT Plus is $20 a month. That's $240 a year, forever, to rent access to a model running on someone else's computer, trained on your conversations' worth of context, with your data policy set by a company whose revenue plans keep changing.

> And they are changing. OpenAI is reportedly projecting Plus subscriptions falling from about 44 million to around 9 million, with the gap backfilled by an $8/month **ad-supported** tier.

> Read that again. The mainstream answer to "I don't want to pay $20 a month" is now: *then watch ads.*

> That's the whole industry pattern. Pay, or be the product. NOBS refuses both.

> Meanwhile the alternative got genuinely good. Ollama went from roughly 100,000 downloads a month in early 2023 to about **52 million** in early 2026. Running a capable model at home stopped being a hobbyist stunt. A $500 GPU — or the Mac already on your desk — runs everyday models fine, at roughly $50–150 a year in electricity even under heavy use.

> **The honest ceiling:** for everyday drafting, summarizing, planning, and coding help, a good local model holds its own. For the hardest reasoning and the longest documents, frontier cloud models are still ahead. I'm not going to pretend otherwise — if I did, you'd find out in a week and never trust anything else on this page.

---

## 3. What works today vs. what's coming

**Section heading:** *Exactly where this is. No roadmap fog.*

**Intro line:** Three labels. Nothing on this page gets a fourth.

- **✅ Works today** — running, tested, you can use it.
- **🧪 Built, being verified** — the code exists and passes tests; it isn't in your hands yet.
- **🔜 Coming soon** — designed and documented, not built. Not a promise with a date.

### ✅ Works today — the Tank (your server)

- ✅ Works today — FastAPI + Ollama (`qwen3:8b`) server on your own PC or Mac
- ✅ Works today — Chat with a tool-using agent, restricted to an allowlisted tool registry
- ✅ Works today — Every state-changing action goes through a stored, atomic, non-replayable approval queue
- ✅ Works today — Full audit log of what the agent proposed, what you approved, what ran
- ✅ Works today — Separate Personal / Business / Shared contexts that never silently mix
- ✅ Works today — Daily briefing generation with a privacy receipt on every one
- ✅ Works today — Calendar and reminders sync endpoints
- ✅ Works today — Overnight task queue that runs only when the machine is idle
- ✅ Works today — Home Assistant bridge (any state change still creates an approval)
- ✅ Works today — Connected-screen dashboard for a spare monitor
- ✅ Works today — Bonjour pairing between iPhone and Tank — no port forwarding, no cloud account
- ✅ Works today — 246 deterministic backend tests, CI on Linux, macOS, and Windows
- ✅ Works today — A macOS menu-bar app (NOBSTank) that turns a Mac into a portable Tank

### ✅ Works today — the iPhone app (with one caveat, below)

- ✅ Works today — Conversational onboarding — no permissions checklist to grind through
- ✅ Works today — Morning Briefing v2: detects schedule conflicts and overloaded days, suggests reversible fixes
- ✅ Works today — Today, Memory, Activity, Home, and Privacy surfaces
- ✅ Works today — Siri and Shortcuts App Intents, plus Home/Lock Screen widgets
- ✅ Works today — Live Activity showing pending approvals on the Lock Screen
- ✅ Works today — Visible **Local** / **Tank** routing badge and a privacy receipt on every response
- ✅ Works today — Honest local fallback when Tank is offline — it says so, it doesn't fake it

### 🧪 Built, being verified

- 🧪 Built, being verified — **The iPhone app is simulator-verified only. TestFlight is opening soon — it is not live yet.**
- 🧪 Built, being verified — NOBScloud paid fallback: coded (StoreKit 2 + Apple Private Cloud Compute routing), gated **off** pending an Apple entitlement. Nobody can use it today.
- 🧪 Built, being verified — When that does go live, it routes through **Apple's** Private Cloud Compute. There is no NOBS server farm, and there isn't going to be one.

### 🔜 Coming soon

- 🔜 Coming soon — Google Home and Alexa unification (Home Assistant bridge works today; those two do not)
- 🔜 Coming soon — Tank Research Library — overnight research with citations
- 🔜 Coming soon — Custom skill generation
- 🔜 Coming soon — NOBSbox — plug-in home hardware

---

## 4. How it works

**Section heading:** *Three pieces. That's the whole architecture.*

**1. The app on your phone.**
SwiftUI, native, conversation-first. Chat, your day, what NOBS remembers, what it wants permission to do.

**2. Tank — a server on hardware you already own.**
A gaming PC, a spare desktop, a Mac. FastAPI plus Ollama. Your phone finds it on your own network via Bonjour. Your conversations, calendar, and context stay on that machine, in your house. Not "encrypted in transit to our secure cloud." *In your house.*

**3. Optional cloud burst — only if you approve it.**
Some jobs are bigger than your hardware. When that happens, NOBS asks. It doesn't decide for you, and it never routes quietly. *(Status: 🧪 Built, being verified — gated off today.)*

### The part I actually care about

Every single response carries a badge: **Local**, **Tank**, or cloud. Tap it and you get a privacy receipt — what data was used, where it was processed, why.

No other assistant will tell you this, because for most of them the honest answer is "all of it, our servers, to improve our services." NOBS shows you the answer on every message because when the answer is boring, you can afford to show it.

---

## 5. Why help, and who I need

**Section heading:** *I'm one person. This is where you'd come in.*

> I'm Alexander. I'm building NOBS in public, alone, and the repo is the whole truth — including the parts that don't work. If the pitch above sounds like something that should exist, here's exactly where a hand would matter.

### Who I need

**Swift / SwiftUI developers**
The iPhone app is real and it's the front door. Widgets, Live Activities, App Intents, and especially accessibility — Dynamic Type, VoiceOver, reduced motion, non-color state indicators. Accessibility here isn't a compliance checkbox bolted on at the end; it's supposed to be how the product adapts to you.

**Python / FastAPI developers**
Tank's agent, its tool registry, and its approval queue. Before you decide whether this is a toy: **246 deterministic tests, CI green on Linux, macOS, and Windows.** New tools need denial tests, replay tests, path-boundary tests, and malformed-model-output tests. If that sounds like your idea of a good time, we'll get along.

**Home Assistant and smart-home people**
The bridge works and every state change creates an approval. What it needs is people with real, messy, multi-vendor houses telling me where the model breaks.

**People with spare hardware**
Tank must run on Windows/WSL2 and Linux, not just the Mac I develop on. CI covers all three; lived experience covers none. If you have a box and an evening, that's genuinely one of the most useful things anyone could give this project.

**Writers and designers**
Docs, onboarding words, the visual system. Making a privacy-first product *feel* warm rather than paranoid is a design problem, and it's not solved.

### Smaller asks that still help

- ⭐ Star the repo — it's how anything gets found
- 🐛 Open an issue — including "your README made no sense to me"
- 🔧 Try the Tank setup and tell me where it hurt — friction reports are worth more than patches
- 💬 Tell me what you'd want it to do. The roadmap isn't sacred.

**Contributor CTA:**
> **github.com/acburgess25/NOBS** — start with `docs/CURRENT_STATE.md`. It's the honest implemented-vs-planned boundary, written for someone arriving with zero context.

---

## 6. What NOBS will never do

**Section heading:** *The short list. These aren't preferences.*

- **Never sell your data.** No ads, no ad tier, no "anonymized insights," no data brokers.
- **Never sell your attention.** Nothing in NOBS is optimized for engagement.
- **Never lock you in.** Open source. Open formats. Export everything — conversations, memories, settings — and walk.
- **Never touch passwords or financial accounts.** Categorically off-limits. Not a setting.
- **Never act without approval.** Every state-changing action is stored, approved by you, executed once, logged, and reversible where possible.
- **Never fake a feature.** If it doesn't work, NOBS says so and offers what it *can* do.
- **Never break what works to sell you an upgrade.** Hardware recommendations require measurable limits, and NOBS suggests software fixes first.

**And the free part stays free.** Local chat, the daily briefing, privacy controls, and use of your own Tank hardware are permanently free. Not free-tier-until-we-raise-a-round. Free.

---

## 7. What's still not true

**Section heading:** *Fine print, but the honest kind.* — **place at the page footer, above sources.**

- **TestFlight is not live.** The iPhone app is verified in the simulator. Physical-device validation and the App Store Connect upload are still pending. "Opening soon" is the accurate phrasing, and it's the only phrasing this site should use.
- **NOBScloud is gated off.** The StoreKit 2 subscription and Apple Private Cloud Compute routing are written and tested, but the Apple entitlement hasn't been granted, so the flags are unset and nobody can route through it. When it ships it will mean **Apple's** infrastructure with an honest label — not NOBS-operated servers.
- **Google Home and Alexa are not unified.** The Home Assistant bridge works today. Those two ecosystems don't. Don't let anyone read the smart-home section as broader than that.
- **No approved long-term memory workflow yet.** The Memory surface exists; the approval loop behind it isn't finished.
- **`tank.local` doesn't resolve on every network.** Some LANs need the Tank host's IP directly. Known, documented, not hidden.
- **Support is a one-time tip link only.** GitHub Sponsors is not enrolled, and the recurring payment link is still a placeholder.

---

## 8. Notes before publishing

- **Re-read `docs/CURRENT_STATE.md` the day this goes live.** The status table in §3 is the entire value of this page — a single stale ✅ costs more credibility than the whole page earns. Specifically check: has TestFlight gone live, have the `NOBSPCC*` flags been flipped, has the recurring Square link been filled in, has GitHub Sponsors been enrolled.
- **Re-run the test count** (`python3 scripts/dev.py check`, or `pytest --collect-only -q`) rather than copying `246` forward. It was accurate on `main` on August 14, 2026; an optimizer route-classification test pending merge will raise it.
- **Do not add a GitHub Sponsors CTA** until `github.com/sponsors/acburgess25` actually shows a Sponsor button. Two separate switches control this: `website/public/support.json` (`githubSponsors`) and the commented-out `github:` key in `.github/FUNDING.yml`. The repo-page button comes from `FUNDING.yml` regardless of what the site renders.
- **Status markers must ship as text.** If the implementation reduces them to colored dots or bare emoji, that breaks the accessibility rule in `PRODUCT_DECISIONS.md` §20 and the non-color-state-indicator rule the app already follows. Push back on that in review.
- **Keep the PCC wording exact** if any of §7 gets reused: subscription-gated, on-device entitlement, routes through Apple's infrastructure, not a hosted NOBS backend. Getting this fuzzy is the fastest way to violate §19.
- **Market numbers are third-party reporting**, not NOBS measurements. Keep the hedges ("reportedly," "roughly," "about") — they're doing real work. If a source has been contradicted by publish time, cut the claim rather than softening it.
- **One line to sanity-check the whole page:** could a stranger glance for fifteen seconds and correctly say what this is and whether it's ready? If §3 doesn't do that alone, the page has failed regardless of how good the prose is.

---

## 9. Sources

Market framing in §2. All third-party reporting; cite or link inline on the live page rather than presenting these as NOBS figures.

1. **ChatGPT Plus pricing and subscriber projections** — Plus is $20/month; OpenAI reportedly projects Plus subscriptions declining from ~44M (2025) to ~9M (2026), offset by an ~$8/month ad-supported "Go" tier. Source: *Where's Your Ed At* (wheresyoured.at).
2. **Ollama adoption** — approximately 52M monthly downloads in Q1 2026, up from roughly 100K monthly in Q1 2023. Sources: gudz.ai/posts/local-ai-llm-tools-2026; neuralcoretech.com/local-ai-self-hosted-llms-2026.
3. **Local inference cost** — roughly $50–150/year in electricity under heavy use, versus $240/year for ChatGPT Plus. Source: codersera.com/blog/cheapest-way-to-run-local-llm-2026.
4. **Hardware floor** — an RTX 5060 Ti 16GB (~$500) or an existing Apple Silicon Mac runs everyday local models well. Source: digitalapplied.com local-AI hardware guide.
5. **Capability ceiling** — best-in-class local models are competitive for everyday drafting, summarizing, and coding assistance, and trail frontier models on hardest-case reasoning and longest-context work. Synthesized from sources 2–4; state it as a general finding, never as a benchmark NOBS ran.

**NOBS-internal claims** (status table, test count, architecture) come from `docs/CURRENT_STATE.md` and `docs/PRODUCT_DECISIONS.md` in the repo, verified August 14, 2026. Those are the citations that matter most — they're public, and anyone can check them.
