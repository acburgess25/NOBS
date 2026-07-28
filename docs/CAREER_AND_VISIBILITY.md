# Career Visibility and Job-Market Plan

**Status:** Proposed operating plan (Alexander Burgess)  
**Captured:** July 28, 2026  
**Companion:** [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md) (NOBS as a business)  
**Public hygiene:** [`PUBLIC_RELEASE.md`](PUBLIC_RELEASE.md)

NOBS is both a product and a **proof portfolio**. This plan is how to turn that work into marketable skills, public credibility, and job offers—without fake hustle or overclaiming unfinished features.

---

## Dual outcome

| Track | Goal |
|-------|------|
| **Business** | Tips, TestFlight users, later paid capability ([`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md)) |
| **Career** | Recruiters and hiring managers can see shipped systems work and want to talk |

Same artifacts serve both: a public app, honest docs, clean GitHub history, and short write-ups of hard problems you solved.

---

## What NOBS already proves (lead with these)

Hiring managers buy **evidence**, not roadmaps. Package NOBS as concrete skills:

| Skill cluster | Evidence in this repo |
|---------------|------------------------|
| **iOS / SwiftUI** | Chat-first app, onboarding, Today briefing, widgets, Live Activities, App Intents / Siri, deep links, StoreKit scaffold, Sign in with Apple |
| **Privacy-aware product engineering** | Processing labels, privacy receipts, progressive permissions, local-first routing |
| **Backend / APIs** | FastAPI Tank service, auth, sync, briefing, deterministic tests |
| **Local AI / agents** | Ollama bridge, allowlisted tools, approval queue, Personal/Business/Shared contexts |
| **Cross-platform systems** | Linux Tank, macOS NOBSTank, Windows/WSL2-aware scripts, CI matrix mindset |
| **Shipping / ops** | TestFlight/signing pipelines, systemd deploy templates, dashboard kiosk, Cloudflare tunnel site |
| **Product judgment** | Written product decisions, honest “coming soon,” accessibility as default |

**Positioning line (use everywhere):**

> I build privacy-first consumer systems end-to-end—SwiftUI on device, FastAPI + local models at home, and clear product boundaries so unfinished work is never sold as done.

Pick **one primary target role** so outreach stays sharp:

1. **iOS / Apple platforms engineer** (default if App Store + TestFlight ship soon), or  
2. **Full-stack / platform engineer** (API + client + deploy), or  
3. **AI product / applied ML engineer** (agents, tooling, safety rails—not “I fine-tuned a foundation model”).

Secondary interest is fine on LinkedIn; applications and DMs should match one role.

---

## Phase 0 — Marketable today (this week)

### Make the work visible

1. Finish [`PUBLIC_RELEASE.md`](PUBLIC_RELEASE.md) and make the NOBS repo **public** (or keep a polished public mirror if secrets still block a flip). Private work cannot get you offers.
2. GitHub profile: pin NOBS, short bio with the positioning line, link `https://nobsdash.com`.
3. Repo README: 30-second demo GIF/screenshot, stack badges, “what works / what doesn’t,” how to run tests—not a novel.
4. Topics: `swiftui`, `ios`, `fastapi`, `local-ai`, `privacy`, `homelab`, `ollama`.

### Package three “case studies” (one page each)

Write as blog posts on the site or GitHub Discussions / LinkedIn articles. Each needs: problem → constraint → what you built → tradeoff → link to code.

Suggested first three (all shippable from current work):

1. **Approval-gated local agent** — model proposes, user authorizes; no arbitrary shell.
2. **Local / Tank / cloud routing with privacy receipts** — policy-driven ModelRouter.
3. **Morning briefing from Calendar + Focus** — mental-load product in SwiftUI + EventKit.

Do not wait for Memory or Google Home to “feel complete.” Unfinished scope is a feature of honesty.

### Profiles that get you found

| Surface | Action |
|---------|--------|
| **LinkedIn** | Headline = role + NOBS one-liner; Featured = site + TestFlight (when live) + best post; Open to Work (recruiters only if preferred) |
| **nobsdash.com** | Personal Workshop page already fits; add a clear **About / Hire me** block: role target, stack, email or LinkedIn |
| **GitHub** | Green activity from real commits; meaningful PR descriptions |
| **Apple Developer** | TestFlight public link as “shipped on real devices” proof |

### Outreach that works without spam

- 5–10 thoughtful messages/week: alumni, engineers at target companies, iOS/AI meetup hosts—**reference a specific thing you built**, ask one question or offer a 15-min walkthrough of the agent approval design.
- Apply to roles that match the evidence (SwiftUI, platform, privacy, developer tools, local/edge AI)—not every “AI” listing.
- Post weekly: one screenshot or 45s clip + what you learned. Same cadence as the product build-in-public notes.

**Definition of done for Phase 0:** public repo (or public showcase), LinkedIn + site aligned, three case-study drafts started, first week of posts/outreach logged.

---

## Phase 1 — Portfolio that survives a screen share

Hiring loops end in “show me the code” or a live demo.

1. **Ship TestFlight** — strangers installing your app beats any résumé bullet ([`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md)).
2. **Record a 3-minute demo:** onboarding → briefing → Local/Tank badge → approve/deny a Tank action → Privacy/Support. Upload unlisted YouTube; embed on site and LinkedIn.
3. **Keep CI green** on `main` so a recruiter cloning the repo does not hit a wall.
4. **One polished deep dive** (README section or doc): architecture diagram from [`CODEBASE_REFERENCE.md`](CODEBASE_REFERENCE.md), plus how you would extend it in a team setting.
5. **Talk track for interviews:** privacy vs capability tradeoffs, why approvals are atomic, why free core stays free, how you’d productionize NOBScloud entitlements.

Optional stretch that signals seniority: a short design doc you wrote *before* implementing a slice (you already have specs under `docs/`).

---

## Phase 2 — Convert attention into offers

### Funnel

```
Public ship / post → profile visit → TestFlight or repo clone
                  → conversation → take-home or screen share
                  → onsites → offer
```

### Offer-seeking tactics

- **Target list:** 15–30 companies (Apple ecosystem shops, privacy-minded startups, developer tools, local/edge AI, consumer productivity). Track status in a private note—not in the public repo.
- **Referrals > cold apply.** Use the weekly posts as referral bait: “I shipped X; if your team needs Y, I’m looking.”
- **Contract / freelance bridge** if full-time is slow: small SwiftUI or FastAPI gigs funded by the same public proof; still ship NOBS weekly so the portfolio stays warm.
- **Negotiate with evidence:** TestFlight users, Sponsors/tips, architecture write-ups—not “I plan to.”

### What to practice

- Live coding in Swift *or* Python (match the role you’re applying for).
- System design: “personal assistant with local and cloud models” using your real constraints.
- Behavioral: times you chose honesty over feature theater (coming-soon policy).

---

## Phase 3 — Keep compounding after an offer

Whether you join a company or keep building NOBS:

- Retain public build-in-public rights where your employer allows (or keep a personal fork of non-confidential lessons).
- Prefer roles that deepen the skill cluster you marketed (platforms, privacy, client+API), so the next leap is easier.
- If NOBS becomes the job (indie + revenue), treat career visibility as customer acquisition; if employment is the goal, treat NOBS as the forever portfolio piece.

---

## Weekly operating rhythm (career + product)

| Day focus | Career | Product |
|-----------|--------|---------|
| Build | Ship one visible slice | Same slice lands in TestFlight/docs |
| Write | One post or case-study paragraph | Update CURRENT_STATE if capability changed |
| Connect | 5 outreaches or applications | Collect tester feedback |
| Money | Optional—don’t block on it | Sponsors / tips / IAP per growth plan |

Never skip **Build** for endless profile polishing. Recruiters hire from shipped systems.

---

## Owner checklist

### This week

- [ ] Complete public-repo hygiene ([`PUBLIC_RELEASE.md`](PUBLIC_RELEASE.md)) and flip or publish a showcase
- [ ] Align LinkedIn headline + Featured with positioning line
- [ ] Add Hire-me / contact CTA on `nobsdash.com`
- [ ] Draft case study #1 (approval-gated agent)
- [ ] Post one demo screenshot or clip
- [ ] Send 5 specific outreach messages
- [ ] Short target-company list (private)

### With TestFlight

- [ ] 3-minute demo video
- [ ] Link TestFlight from site, README, LinkedIn
- [ ] Apply to 5 role-matched jobs with NOBS as the lead project

### Ongoing

- [ ] Weekly public ship note
- [ ] Keep interview talk track updated to [`CURRENT_STATE.md`](CURRENT_STATE.md)
- [ ] After each rejection, note the gap (e.g. algorithms vs product) and practice that—not random tutorials

---

## Guardrails

- Do not invent production metrics or claim Memory / full smart-home / NOBScloud are shipped.
- Do not put private keys, home IPs, or personal data in public posts.
- Do not dilute the brand with rage-bait; credibility is the product.
- Job search and NOBS revenue can run in parallel; if time is scarce, **ship TestFlight first**—it feeds both tracks.
