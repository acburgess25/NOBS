# NOBS Funding Strategy

**Status:** Working fundraising plan  
**Updated:** July 2, 2026  
**Owner:** Alexander Burgess

This plan turns the approved NOBS product direction into a financeable sequence. It does not replace [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md); that document remains the source of truth for the product.

## Funding objective

Raise the smallest appropriate round that gives NOBS enough runway to prove that overwhelmed working adults repeatedly use and value a private, Apple-native daily planning assistant.

The financing target should remain a range until the founder's personal runway, incorporation status, hiring plan, and expected infrastructure costs are known. A reasonable planning envelope for an initial angel or pre-seed raise is **$250,000–$500,000**, released only after a bottom-up budget confirms what 12–18 months of focused execution actually costs.

The initial [18-month runway model](../outputs/019f21bc-d69b-7070-b7bb-d30fd6afe86c/nobs_fundraising_runway_model.xlsx) produces an illustrative **$650,000** target from unapproved placeholder assumptions. This is not the approved raise amount; it demonstrates that the earlier planning envelope and the modeled hiring plan cannot both be treated as settled. Founder-approved inputs must resolve the difference.

## What is fundable now

### Core narrative

NOBS is a private personal-intelligence layer for the Apple ecosystem. It turns a chaotic day into a realistic plan, runs locally whenever possible, and makes every escalation to user-owned Tank hardware or optional NOBScloud visible.

### Beachhead

- **User:** overwhelmed working adults who already live in the Apple ecosystem;
- **Pain:** calendars, tasks, messages, and commitments exist in separate inboxes and do not become a feasible plan;
- **Promise:** NOBS finds conflicts, protects priorities, and proposes reversible fixes in seconds;
- **Trust advantage:** local-first processing, explicit permissions, visible processing routes, and no advertising or personal-data business model;
- **Expansion:** communication workflows, household intelligence, private Tank research, smart-home unification, skills, and eventually NOBSbox.

The beachhead should lead every application and investor conversation. The expansion vision demonstrates scale but should not enlarge the first product milestone.

## Current readiness assessment

| Area | Current evidence | Funding implication |
|---|---|---|
| Product thesis | Approved product decisions and PRD | Strong enough for a clear story |
| iPhone/iPad experience | Interactive universal SwiftUI prototype with conflict detection, revised-plan proposal, approval/rejection, and privacy receipt using sample data | Stronger investor demo; still not proof of real utility |
| Backend | FastAPI health/configuration baseline | Shows technical execution, not product demand |
| Public presence | In-development portfolio site and screenshots | Useful credibility layer; needs a user/research conversion path |
| User evidence | No repository-backed interview, usability, retention, or willingness-to-pay evidence yet | Principal fundraising gap |
| Commercial proof | Revenue model is defined; pricing and conversion evidence are not | Keep financial projections explicitly assumption-based |

## Investor-ready proof point

The first proof point is not the complete NOBS vision. It is a trustworthy end-to-end demonstration of this claim:

> Given a real person's calendar, tasks, and stated priorities, NOBS identifies an overloaded day, proposes a realistic plan, explains why, and lets the person approve or reject reversible changes.

### Required product behavior

1. Import or accept a real participant's schedule and priorities with informed consent.
2. Identify conflicts, missing transition time, and unrealistic capacity.
3. Produce a prioritized daily plan with a brief explanation.
4. Offer at least one reversible adjustment.
5. Display where processing occurred and what information was used.
6. Capture whether the proposed plan was accepted, edited, or rejected.
7. Return the next day with enough continuity to test repeated value.

### Proof thresholds

These thresholds are a decision gate, not claims about statistical certainty:

- 15 target-user discovery interviews;
- 10 consented prototype trials using a participant's real or participant-approved representative day;
- at least 6 participants who use the planning loop on 3 separate days within 14 days;
- at least 5 participants who say they would be meaningfully disappointed to lose it;
- at least 4 participants who make a credible pricing commitment: paid pilot, refundable deposit, or explicit purchase intent at a tested price;
- no unresolved critical privacy misunderstanding in the exit interview;
- documented quotations and observations, with permission and identifying details removed.

Passing these thresholds justifies beginning a focused angel/pre-seed process. Missing them means revise the problem, audience, or workflow before raising a larger round.

## Ninety-day financing path

### Phase 1 — Make the wedge real (weeks 1–4)

- Replace the static agenda path with the narrow daily-planning loop.
- Use read-only inputs first; do not require production billing, broad smart-home support, or full NOBScloud.
- Instrument activation, plan acceptance, edits, return usage, latency, processing route, and failure reasons without storing private content.
- Create a two-minute founder-led demo that shows the problem, product behavior, and privacy receipt.

**Gate:** five internal or friendly-user dry runs complete without misleading capability claims or privacy confusion.

### Phase 2 — Validate demand (weeks 2–7)

- Recruit 15 overwhelmed working adults across individual contributors, managers, caregivers, and neurodivergent users who self-identify with planning overload.
- Run problem interviews before demonstrating the product.
- Invite qualified participants into the 14-day prototype trial.
- Test willingness to pay with concrete price points rather than “would you pay?” questions.
- Publish a weekly evidence summary: what was observed, what changed, and what remains uncertain.

**Gate:** meet the proof thresholds above or record a product decision explaining the pivot.

### Phase 3 — Package the raise (weeks 5–8)

- Finalize a 10-slide deck, two-minute demo, one-page brief, founder biography, product roadmap, use-of-funds model, and basic data room.
- Incorporate and clean up IP ownership before accepting investment, if not already complete.
- Choose a standard financing instrument with startup counsel; do not invent bespoke terms.
- Build a target list scored by stage fit, consumer/AI/privacy thesis, check size, geography, and strength of introduction path.

**Gate:** every factual claim in the deck maps to evidence in the data room.

### Phase 4 — Run a concentrated process (weeks 8–12)

- Start with 10–15 feedback conversations with founders, operators, and low-risk investors.
- Incorporate repeated objections before the main outreach wave.
- Run warm introductions first, then tightly personalized direct outreach.
- Cluster first meetings into a short window to create comparable momentum.
- Track each target through researched, intro requested, contacted, meeting, diligence, pass, and committed.
- Send concise weekly investor updates containing proof, progress, learning, and a specific ask.

**Gate:** continue, resize, or pause the round based on meeting conversion, diligence progression, and product evidence—not politeness.

## Recommended funding ladder

1. **Founder-funded validation:** enough to complete interviews and a truthful prototype.
2. **Accelerator applications:** prioritize programs whose timing and terms improve the odds of reaching product proof. Y Combinator's Fall 2026 application is the clearest live deadline currently identified; its published on-time deadline is July 27, 2026.
3. **Operator angels:** Apple ecosystem, consumer subscriptions, privacy infrastructure, local AI, productivity, and accessibility operators.
4. **Chicago and Midwest early-stage network:** use local founder and investor communities to build warm paths rather than treating geography as the thesis.
5. **Institutional pre-seed funds:** approach after the working planning loop and early return-use evidence exist.
6. **Non-dilutive funding:** pursue only when the funded technical research matches planned work. Illinois lists an SBIR/STTR matching program, but it requires a qualifying federal award and is not a substitute for customer validation.

## Raise design

### Milestones the round should purchase

- a reliable iOS daily-planning beta;
- validated EventKit and task-context ingestion with privacy-safe fallbacks;
- a small but active cohort demonstrating repeated use;
- evidence-backed pricing and NOBScloud packaging;
- trust, routing, and privacy evaluations;
- a credible path from founder-built prototype to a supportable product.

### Illustrative use of funds

Do not publish percentages until a bottom-up budget exists. The budget should separately model:

- founder runway;
- iOS/product engineering;
- design and user research;
- security/privacy review and legal costs;
- cloud and model evaluation costs;
- insurance, accounting, and company administration;
- recruiting and participant compensation;
- a contingency reserve.

### Financing guardrails

- Do not raise for NOBSbox hardware in this round.
- Do not claim retention, market size, model performance, or privacy guarantees without evidence.
- Do not let investors redefine the business around advertising, data brokerage, lock-in, or artificial hardware limits.
- Do not optimize valuation at the expense of a clean cap table and genuinely useful investors.
- Have qualified counsel review incorporation, IP assignment, securities documents, and investor terms.

## Investor target scorecard

Score each target from 0–2 on each dimension. Prioritize totals of 8 or higher out of 10.

| Dimension | 0 | 1 | 2 |
|---|---|---|---|
| Stage/check fit | Wrong | Adjacent | Exact |
| Thesis fit | None | General AI/consumer | Consumer AI, privacy, local compute, Apple/productivity |
| Evidence expectation | Requires traction beyond current stage | Unclear | Invests at prototype/early-validation stage |
| Value beyond money | Little | General network | Relevant product, distribution, hiring, or security expertise |
| Access path | Cold and weak | Credible direct path | Trusted warm introduction |

## Pipeline fields

Maintain one row per investor or program with:

- target and partner;
- website;
- stage and typical check;
- thesis evidence;
- why NOBS fits;
- introduction path;
- status and last interaction;
- next action and owner;
- objections or diligence requests;
- pass reason;
- source and last verified date.

Never scrape or mass-message a generic investor list. Twenty well-researched targets are more useful than hundreds of names without fit or access.

## Materials checklist

- [x] Working [one-page investor brief](INVESTOR_BRIEF.md); founder and raise facts remain incomplete
- [x] Working [ten-slide deck narrative](PITCH_DECK.md); design and evidence replacement remain incomplete
- [ ] Two-minute product demo
- [ ] Founder biography and founder-market-fit explanation
- [ ] Validation evidence summary
- [ ] Product roadmap tied to financing milestones
- [x] Working [bottom-up 18-month runway model](../outputs/019f21bc-d69b-7070-b7bb-d30fd6afe86c/nobs_fundraising_runway_model.xlsx); founder-approved inputs and final raise target remain incomplete
- [ ] Cap table and incorporation records
- [ ] Founder and contractor IP assignments
- [ ] Security and privacy overview
- [x] [Data room index](DATA_ROOM.md); underlying diligence documents remain incomplete
- [x] Working [investor shortlist and pipeline](FUNDING_TARGETS.md); founder-level routes and outreach remain incomplete
- [x] [Warm-introduction request and direct-outreach copy](OUTREACH_PLAYBOOK.md)
- [x] [Monthly investor update template](OUTREACH_PLAYBOOK.md)

## Immediate decisions required from the founder

1. Is NOBS incorporated, and if so where and under what legal name?
2. Is the founder working full time on NOBS? If not, what financing milestone would make that possible?
3. What minimum personal runway must the round cover?
4. Are there cofounders, contractors, prior employers, or reused assets that affect IP ownership?
5. Is relocating or participating in an in-person accelerator acceptable?
6. Which parts of the founder's background create a credible right to build NOBS?

Those answers determine the actual raise size, financing path, and investor list.

## Sources to re-verify before applying

- [Y Combinator application](https://www.ycombinator.com/apply/) — Fall 2026 timing and application status; verified July 2, 2026.
- [Illinois DCEO grant opportunities](https://dceo.illinois.gov/aboutdceo/grantopportunities/grants.html) — SBIR/STTR Match Program availability and eligibility; verified July 2, 2026.

Program dates, terms, and eligibility can change. Re-check the official source immediately before submitting or making a financing decision.
