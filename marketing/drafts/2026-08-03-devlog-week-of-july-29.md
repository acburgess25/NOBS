# Devlog — week of July 29

**Status:** Draft. Written from merged commits in `git log`; every claim below matches `docs/CURRENT_STATE.md` as of Aug 3, 2026. Do not add anything that isn't true yet — TestFlight is still not live.
**Where this would go:** the "build-in-public" section of nobsdash.com (if/when one exists) and/or a GitHub Discussions post, cross-posted short-form to X/LinkedIn. Not Reddit — the two existing Reddit drafts already cover that channel.

## Title options

- "What shipped this week: a real money path, a safer Tank, and a site that doesn't look like a template"
- "NOBS devlog: paid fallback, an honest empty state, and closing a token leak"

## Body (long-form)

This week's work on NOBS, the local-first personal assistant I'm building, in plain language — no roadmap talk, just what actually landed.

**1. NOBScloud has a real (if early) shape now.**
Until this week, the paid subscription in the app was a dead end — you could buy it, and then... nothing happened, because there was no backend to route to. Now, when your own Tank server is offline and you've paid for NOBScloud, the app can fall back to Apple's Private Cloud Compute instead of just failing. The privacy receipt is explicit about it: this is Apple PCC under the NOBScloud label, not some NOBS-run server in the cloud, because that server doesn't exist yet and I'm not going to pretend it does. If PCC isn't available either, you get an honest "can't reach that right now" instead of a silent wall.

**2. Fixed a bug that would've embarrassed a tester.**
The in-app Support screen, when App Store Connect products weren't loaded yet, was showing copy written for *me* ("add the products in App Store Connect") to whoever tapped the screen — plus, in some cases, a raw StoreKit error dialog stacked on top of it. Neither of those should ever reach a real user. Split the failure paths apart so a missing product now shows calm "coming soon" copy instead of a developer's TODO note or a stack trace.

**3. Closed a real token-exposure gap on Tank.**
The device token that authenticates every request to Tank — chat, agent tools, approvals, all of it — was showing up in places it shouldn't: an unauthenticated dashboard status endpoint, and a pairing flow that would accept the wrong kind of Apple ID and hand the token back. Both are closed now. The dashboard status endpoint tells you the Tank address and whether a token is configured — nothing more — and the token itself only comes back through a pairing endpoint that checks who's asking first. This is the kind of fix that doesn't come with a screenshot, but it's exactly the kind of thing "local-first" has to mean in practice, not just in a pitch.

**4. The website stopped looking like a placeholder.**
Rebuilt nobsdash.com around a calmer full-viewport hero, warmer cream/sage color washes, and a real tip CTA using Square Payment Links (no Stripe account needed to get that live). It's hosted straight off `main` via GitHub Pages now instead of a separate deploy step, so the site and the code can't drift out of sync.

**What's still not true:** TestFlight isn't public yet — that's still the single biggest unlock (App Store Connect signing + tax/banking are the remaining blockers, not code). Long-term Memory, unified smart-home control, and hosted NOBScloud servers are all still "coming soon," not "coming."

Repo: https://github.com/acburgess25/NOBS

## Body (short-form, X / LinkedIn)

Shipped this week on NOBS (local-first personal assistant, open source):

- A real (early) path for the paid tier to actually do something when your home server's offline — routes through Apple Private Cloud Compute, labeled honestly, no fake cloud servers
- Fixed a Support screen bug that would've shown testers developer notes and raw error dialogs
- Closed a token-exposure gap in the home-server auth flow
- Site redesign + hosting moved onto GitHub Pages from `main`

Still not live: TestFlight. That's next.

https://github.com/acburgess25/NOBS

## Notes before posting

- Item 3 (the token fix) is real security hardening already merged and public in git history — summarizing it here is normal changelog practice, not a new disclosure. Do not add exploit detail beyond what's already in the public commit message.
- Do not imply TestFlight is close to a date. "Next" is fine; a date is not, per `docs/CURRENT_STATE.md` and the honesty rule in `PRODUCT_DECISIONS.md` §19.
- If posting to LinkedIn, the long-form body reads fine as-is; X should use the short-form and split across 2 posts if needed for length.
