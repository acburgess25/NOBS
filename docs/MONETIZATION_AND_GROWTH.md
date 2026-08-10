# NOBS Monetization and Growth Plan

**Status:** Proposed operating plan (decision owner: Alexander Burgess)  
**Captured:** July 28, 2026  
**Product constraints:** [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §21–§24  
**Payments ops:** [`SUPPORT_AND_PAYMENTS.md`](SUPPORT_AND_PAYMENTS.md), [`APP_STORE_IAP_SETUP.md`](APP_STORE_IAP_SETUP.md)  
**Distribution gate:** [`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md)

This plan answers two questions:

1. How does NOBS start taking money **now**, without selling data or locking the free core?
2. How does the business deepen as users and cash increase?

A parallel track—using the same shipping work to get job offers and public credibility—is in [`CAREER_AND_VISIBILITY.md`](CAREER_AND_VISIBILITY.md).

It does **not** change the brand promise. NOBS still makes money from optional capability, hardware, and services—not attention or personal data.

---

## North star

**Distribution unlocks revenue and hiring interest.** Until strangers can install NOBS, tip jars, subscriptions, and portfolio proof stay theoretical.

**Integrity unlocks trust.** Charge for capacity and convenience that actually work. Tips and early-supporter subscriptions are fine while cloud features are labeled coming soon; do not market unfinished NOBScloud as a finished product.

**Free core stays free forever:**

- local private chat
- basic daily briefing
- calendar / reminders / Focus
- memory review and export
- privacy controls
- basic local smart-home control
- user-owned Tank hardware
- safety updates and skill scanning

Paid layers sit **above** that floor.

---

## Honest starting position (July 2026)

| Asset | State | Money implication |
|-------|--------|-------------------|
| iPhone app (chat, Today, widget, Tank optional) | Simulator-verified prototype | Can delight early users once TestFlight ships |
| StoreKit tip jar + NOBScloud monthly | Code + local StoreKit config ready | Needs Paid Apps agreement + ASC products + live build |
| Website `nobsdash.com` | Live | Can take Square Payment Links / Sponsors today |
| GitHub Sponsors | URL wired (`acburgess25`); listing may still need enabling | Usable once Sponsors is activated |
| Square / card Payment Links | One-time tip link live in `support.json` (`cardProcessor: square`); monthly link not created yet | Fastest card checkout for web |
| Stripe Payment Links | Optional alternative | Helper script still available |
| NOBScloud backend entitlements | On-device StoreKit only; PCC paid fallback coded | Do not claim hosted NOBScloud servers yet |
| Hosted Tank / NOBSbox / paid skills | Planned | Later revenue, not day-one |

**Bottleneck:** App Store Connect capability / distribution signing for TestFlight. Home Mac + Apple Developer portal actions unblock almost everything else.

---

## Phase 0 — Make money today (no new product required)

Goal: open every cash path that does not depend on shipping unfinished cloud features.

### 0A. Web support (same day)

1. Confirm GitHub Sponsors is active and linked from the site (`website/public/support.json` → `githubSponsors`).
2. Done: one-time Square tip link is created and filled in as `donateOneTime`. Remaining: create a monthly/recurring **Square** Payment Link (Square Dashboard → Payment Links).
3. Fill `donateMonthly` in `support.json` (`cardProcessor` already `"square"`), rebuild and deploy the site.
4. Put a single clear CTA on the homepage and README: **Support the free local core** → Sponsors / tip / (soon) in-app Support.

Rules:

- Frame as support for an independent privacy-first assistant, not charity theater.
- Do not imply tips unlock features.
- Keep Apple IAP as the only path for in-app digital goods once the app is live.

### 0B. Apple money plumbing (same day / this week at home)

1. Sign **Paid Applications Agreement**; finish tax and banking in App Store Connect.
2. Create the four product IDs from [`APP_STORE_IAP_SETUP.md`](APP_STORE_IAP_SETUP.md):
   - tips `$2.99` / `$4.99` / `$9.99`
   - NOBScloud monthly `$4.99` (early supporter; features marked coming soon until backend ships)
3. Add a sandbox tester; verify **Privacy → Support NOBS** with StoreKit config, then sandbox on device.
4. Update App Review notes: tips = optional, subscription = future optional capacity, free tier remains useful alone.

### 0C. Unblock distribution (this week — highest leverage)

Without this, Phase 0 tips stay web-only and growth stalls.

1. Fix App ID capabilities (App Groups + Sign in with Apple) per [`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md).
2. Archive and upload (`./scripts/stage-testflight-ipa.sh` or CI TestFlight workflow).
3. Complete external TestFlight beta review with honest “what works / coming soon” copy.
4. Capture fresh screenshots for App Store Connect and `nobsdash.com`.

**Definition of done for Phase 0:** a stranger can install NOBS from TestFlight, use briefing/chat locally, and tip via web and/or in-app; Paid Apps is live.

---

## Phase 1 — Push the app out (audience before upsell)

Goal: get the launch persona—overwhelmed working adults who care about privacy—into the product.

### Positioning (one sentence)

> NOBS turns a chaotic day into a realistic plan on your iPhone—private by default, optional Tank at home, no tracking.

### Channels that fit the brand

| Channel | What to ship | Avoid |
|---------|--------------|--------|
| TestFlight public link | Primary install path | Overpromising Google/Amazon home or Memory |
| `nobsdash.com` | Demo video / screenshots, privacy policy, support CTA | Corporate SaaS landing clutter |
| Build-in-public (X, Mastodon, Bluesky, LinkedIn, Reddit r/privacy, r/selfhosted) | Short clips of morning briefing → plan | Engagement-bait outrage without product proof |
| Apple-focused communities | Local-first + Sign in with Apple story | Claiming “replacement for ChatGPT” |
| Homelab / Home Assistant crowds | Tank + HA bridge as power-user path | Making Tank sound required |

### Cadence

- Ship a weekly public build note: one shipped improvement, one honest gap, one ask (feedback or tip).
- Collect waitlist email only if optional and privacy-safe; prefer TestFlight + GitHub Discussions initially.
- Every public claim must match [`CURRENT_STATE.md`](CURRENT_STATE.md).

### Conversion funnel (simple)

```
Discover → TestFlight install → first briefing in < 2 min
        → optional Tank pair
        → Support / tip / early NOBScloud
```

Optimize the first briefing, not the paywall. A free user who trusts NOBS is worth more than a coerced subscriber who churns.

**Definition of done for Phase 1:** recurring external testers, public feedback loop, measurable installs, first real tip or Sponsor dollars.

---

## Phase 2 — First paid capability that earns its keep

Goal: turn early-supporter energy into a subscription people keep because it **does something**.

Ship **one** paid wedge before broadening:

### Recommended wedge order

1. **NOBScloud burst when Tank is away**  
   Secure fallback via Apple Private Cloud Compute with visible privacy receipts, on-device StoreKit entitlement (`hasNOBScloud`), hard honesty when PCC is unavailable, and Local/Tank/Apple Cloud badges. Hosted NOBScloud API + entitlement sync remain a follow-on.

2. **Hosted Tank for people without a GPU box**  
   Same Tank API, operated for them. Price above raw compute; sell “always-on private assistant brain” without hardware.

3. **One-time advanced local unlock** (if cloud is delayed)  
   Example: deeper overnight research library, higher automation limits, or family household profiles—**only** if the free core stays intact and the unlock is real.

### Pricing posture (starting point)

| Offer | Starter price | Notes |
|-------|---------------|--------|
| Tips | $2.99–$9.99 | No entitlements |
| NOBScloud monthly | $4.99 | Raise only after delivered cloud value |
| Family (later) | ~1.5–2× individual | Shared household, private profiles |
| Hosted Tank (later) | Separate SKU | Hardware + ops cost drives floor |

Until entitlements sync to Tank/API, keep NOBScloud marketing as **early supporter / coming soon capacity**, not “unlimited AI in the cloud.”

**Definition of done for Phase 2:** paid users receive a capability free users cannot get; restore purchases work; privacy receipts still show where processing happened.

---

## Phase 3 — Recurring business (after product-market proof)

Trigger: people recommend NOBS unprompted, tips are steady, and at least one paid capability has low refund/churn noise.

Then expand in this order:

1. **Family plans** — household profiles, shared vs personal memory boundaries.
2. **Paid community skills revenue share** — after Skill Policy scanning is real ([`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §14).
3. **Business / workplace plans** — Shared context already exists in the agent; sell team coordination without becoming a surveillance suite. Passwords and financial accounts stay off-limits.
4. **Raise NOBScloud tiers** — higher research/automation budgets, not darker patterns.

Reinvest order when cash appears:

1. Apple Developer + infra costs (keep TestFlight/App Store healthy)
2. Customer support path (email / GitHub) so reviews do not die
3. One engineer-week of the highest-retention paid wedge
4. Marketing that shows the product, not ads that buy vanity installs
5. Hardware prototyping only after software retention is proven

---

## Phase 4 — Hardware and scale (when software pull exists)

**NOBSbox** remains the long-term appliance play ([`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §22):

- Sell only when software demand for always-on local Tank is clear.
- Upgrade recommendations stay honest (measurable limits, never degrade features to force upgrades).
- Compare cloud burst cost vs hardware upgrade for the user.

Until then: Mac NOBSTank + DIY Ubuntu Tank are the proof that local NOBS works without a proprietary box.

---

## What not to do (even under money pressure)

- Sell personal data, attention, or dark-pattern upgrade nagging.
- Put the morning briefing or local chat behind a paywall.
- Charge for safety updates or skill scanning.
- Ship a subscription that only shows a “coming soon” wall with no early-supporter honesty.
- Promise Google/Amazon home unification or Memory before they work.
- Spend growth budget on ads before TestFlight + first briefing conversion are solid.

---

## Owner checklist — do these in order

### Today / this week (home + ops)

- [x] Square one-time tip link → `support.json` → deployed site
- [ ] Square monthly (recurring) Payment Link → `support.json` → deploy site
- [ ] Confirm Sponsors CTA visible on site and README
- [ ] Paid Apps + tax/banking in App Store Connect
- [ ] Create IAP product IDs; sandbox test Support screen
- [ ] Fix App ID capabilities; upload TestFlight build
- [ ] External TestFlight group + honest “What to Test”
- [ ] Fresh screenshots on site and ASC
- [ ] Career track: public repo hygiene, LinkedIn/site Hire-me CTA, first case study ([`CAREER_AND_VISIBILITY.md`](CAREER_AND_VISIBILITY.md))
- [ ] On the home Mac: run the Codex Apple audit prompt ([`CODEX_APPLE_ACCOUNT_AUDIT_PROMPT.md`](CODEX_APPLE_ACCOUNT_AUDIT_PROMPT.md)) — inventory, NOBS-only cleanup dry-run, then approve execute

### Next product slice (engineering)

- [x] NOBScloud Tank-away fallback routes through Apple PCC when entitled/available (on-device StoreKit)
- [ ] Stabilize physical-iPhone briefing → widget → optional Tank loop
- [ ] Entitlement sync for NOBScloud (StoreKit → backend) before multi-device / hosted cloud API
- [ ] Enable `NOBSPCC*` flags after entitlement QA so paid fallback is live in production builds
- [ ] Update [`CURRENT_STATE.md`](CURRENT_STATE.md) whenever a paid claim becomes true
- [ ] Record 3-minute demo for portfolio + hiring loops

### After first revenue

- [ ] Simple monthly ledger: Sponsors, Stripe, IAP, Apple fees, infra
- [ ] Pick one retention metric (e.g. weekly briefing opens) and one revenue metric
- [ ] Decide family vs hosted Tank as the next SKU from actual user asks

---

## Decision rule

When a monetization idea conflicts with privacy, free local core, or honesty about capability, **kill the idea**. When it conflicts only with sequencing, prefer the option that puts a working app in more hands first.

Approved product principles remain in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). This document is the operating sequence for turning those principles into a business.
