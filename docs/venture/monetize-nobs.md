# Monetize NOBS — Go-To-Market Brief (v1)

> Source: NOBS venture brain. Top-ranked idea: **Premium Subscription Model (8.5/10, validated)**.
> Decision is recommended, not done. Approve it in `/agent/proposals`, then execute the build brief below with a local agent.

## The product, in one sentence
NOBS is a **privacy-first, on-device AI manager** that runs entirely on your own hardware — no cloud, no per-token fees — and **learns to improve itself** (skills + venture ideas) as it works.

## Why it's sellable (the defensible wedge)
- **Zero-marginal-cost inference.** Competitors bill per token; NOBS runs on the user's own Mac GPU (MLX). The product costs the operator ~nothing per user.
- **Privacy as a feature, not a wrapper.** Self-hosted local brain = no data leaves the machine. This is the pitch.
- **It's alive.** Auto-improving skills + a venture brain is a *visible* moat, not a static tool.

## Positioning
| For | Who | Message |
|---|---|---|
| Freelancers / indie makers | Fast prototyping, reminders, personal planning | "Your AI manager, on your laptop, free to run." |
| Privacy-conscious pros | No cloud AI at work | "AI that never leaves your machine." |
| Hobbyist devs | Local-first tinkerers | "Self-improving assistant on Apple Silicon." |

## Pricing (recommended v1)
- **Free tier:** core assistant + 1 active skill slot. Purpose: funnel + viral "it's free to run" story.
- **Paid — $9/mo (annual = $72):** unlimited skills, venture/idea engine, home/device integrations, priority support.
- **Pro — $49/mo:** multi-user / small team, shared workspace, custom model (bring your own Ollama/MLX), white-label.
- **Enterprise SaaS (7.5):** later, API + dedicated onboarding. Not v1.

> v1 decision: **Freemium, $9/mo Pro**, one-time founders' discount. Affiliate 30% on paid subs.

## Landing / acquisition decision
- **One-page landing first** (not a full app site): 3 sections — problem → product (30s demo) → pricing + email waitlist.
- **Channel for v1:** Goose recipe/marketplace listing (natural fit for the "sellable unit" angle) + ProductHunt launch + a 1-click `brew`/install script.
- **AARRR north-star:** free→paid activation = *user saves their first real insight with a custom skill*.

## Go/no-go gates before any paid work
1. [ ] One founder question answered: **who is the buyer** (freelancer vs enterprise) — pick one for v1.
2. [ ] 20 email-waitlist signups on the landing page (validates demand w/ $0 spend).
3. [ ] The 1-click install works on a clean Mac.

---

## BUILD BRIEF — for a local agent to execute (machine-readable)

**Mission:** Produce a ready-to-deploy sellable artifact for the Premium Subscription idea (8.5/10).

**Idea id:** from `GET /agent/ideas` (title = "Premium Subscription Model"); mark it `building` via `update_idea` on kickoff, `shipped` on completion.

**Deliverables (in order):**
1. `landing/index.html` — one static page: headline, 30s demo block (screenshot or copy), pricing table (Free / $9 Pro / $49 Pro), email waitlist form (`mailto:` or Formspree), affiliate mention.
2. `landing/COPY.md` — the copy deck: H1, subhead, 3 pain→feature bullets, 3 objections + rebuttals, 4 CTAs.
3. `landing/PRICING.md` — the pricing table locked above, with the $9/mo recommendation + reasoning already accepted.
4. `docs/VENTURE/LAUNCH-CALENDAR.md` — Day-0..Day-14: landing live → waitlist pull → ProductHunt → marketplace listing → cold DM 10 target users.

**Constraints:**
- Static only (GitHub Pages / Vercel), no backend. Waitlist = Formspree or `mailto`.
- Branding: keep it "NOBS," reference "runs on your Apple Silicon, no cloud bill."
- Do NOT claim features that don't exist yet (commit to the current toolset only).
- When done: `update_idea` → `shipped`, and record an insight recommending the launch.

**Acceptance:** landing renders standalone, pricing matches this brief, and the 4 docs exist and are internally consistent.