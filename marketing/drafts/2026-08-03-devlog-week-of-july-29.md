# Devlog — week of July 29

**Status:** Draft. Written from merged commits in `git log`; every claim below matches `docs/CURRENT_STATE.md` as of Aug 3, 2026. Do not add anything that isn't true yet — TestFlight is still not live.
**Where this would go:** the "build-in-public" section of nobsdash.com (if/when one exists) and/or a GitHub Discussions post, cross-posted short-form to X/LinkedIn. Not Reddit — the two existing Reddit drafts already cover that channel.

## Title options

- "What shipped this week: a paid fallback (gated), a safer Tank, and a site that doesn't look like a template"
- "NOBS devlog: PCC groundwork, an honest empty state, and closing two token leaks"

## Body (long-form)

This week's work on NOBS, the local-first personal assistant I'm building, in plain language — no roadmap talk, just what actually landed.

**1. NOBScloud's paid fallback path is built — and it's gated off until it's actually verified.**
Until this week, the paid subscription in the app was a dead end — you could buy it, and then... nothing happened, because there was no backend to route to. Now, when your own Tank server is offline and you've paid for NOBScloud, the code path exists for the app to fall back to Apple's Private Cloud Compute instead of just failing. It's not live in the current build, though: the PCC feature flags and entitlement aren't turned on yet, so today's release still just goes local when Tank is away. That switch flips after entitlement QA on a real device — until then this is "built," not "shipped." The privacy receipt design is explicit about what it *will* say once it's on: this is Apple PCC under the NOBScloud label, not some NOBS-run server in the cloud, because that server doesn't exist yet and I'm not going to pretend it does.

**2. Fixed a bug that would've embarrassed a tester.**
The in-app Support screen, when App Store Connect products weren't loaded yet, was showing copy written for *me* ("add the products in App Store Connect") to whoever tapped the screen — plus, in some cases, a raw StoreKit error dialog stacked on top of it. Neither of those should ever reach a real user. Split the failure paths apart so a missing product now shows calm "coming soon" copy instead of a developer's TODO note or a stack trace.

**3. Closed two real token-exposure gaps on Tank — with one honest gap still open.**
The device token that authenticates every request to Tank — chat, agent tools, approvals, all of it — was showing up in places it shouldn't: an unauthenticated dashboard status endpoint, and a pairing flow that let the first caller to reach an unpaired Tank simply claim it. Both of those are closed now — the dashboard only reports the Tank address and whether a token is configured, and claiming an unpaired Tank requires opening a pairing window on the Tank itself first. What's *not* fully closed yet: once a Tank is already paired, re-authenticating still checks the Apple identifier by string match rather than verifying a signed Apple credential end to end, so that verification step is still on the list, not done. This is the kind of fix that doesn't come with a screenshot, and it's not finished — but it's exactly the kind of thing "local-first" has to mean in practice, not just in a pitch.

**4. The website stopped looking like a placeholder.**
Rebuilt nobsdash.com around a calmer full-viewport hero, warmer cream/sage color washes, and a tip CTA wired up for Square Payment Links (no Stripe account needed once the links go live). It's hosted straight off `main` via GitHub Pages now instead of a separate deploy step, so the site and the code can't drift out of sync.

**What's still not true:** TestFlight isn't public yet — that's still the single biggest unlock. The remaining blockers aren't just App Store Connect signing and tax/banking; Apple currently rejects uploads built with the Xcode 27 beta toolchain we're on, so a supported release/RC Xcode has to ship before an upload can even go through, on top of the account paperwork. The NOBScloud PCC fallback described above is code-complete but flag-gated off pending entitlement QA. Long-term Memory, unified smart-home control, and hosted NOBScloud servers are all still "coming soon," not "coming."

Repo: https://github.com/acburgess25/NOBS

## Body (short-form, X / LinkedIn)

Shipped this week on NOBS (local-first personal assistant, open source):

- Built (but not yet flag-enabled) a path for the paid tier to do something when your home server's offline — routes through Apple Private Cloud Compute, labeled honestly, no fake cloud servers
- Fixed a Support screen bug that would've shown testers developer notes and raw error dialogs
- Closed two token-exposure gaps in the home-server auth flow; one more hardening step still open
- Site redesign + hosting moved onto GitHub Pages from `main`

Still not live: TestFlight. That's next.

https://github.com/acburgess25/NOBS

## Notes before posting

- Item 3 (the token fixes) is real security hardening already merged and public in git history — summarizing it here is normal changelog practice, not a new disclosure. Do not add exploit detail beyond what's already in the public commit message, and keep the "one step still open" line — do not round it up to "fully closed."
- Item 1 (PCC fallback) is code-complete but disabled by feature flag pending entitlement QA — say "built" / "gated," never "live" or "now falls back," until `docs/CURRENT_STATE.md` says the flags are on.
- Do not imply TestFlight is close to a date. "Next" is fine; a date is not, per `docs/CURRENT_STATE.md` and the honesty rule in `PRODUCT_DECISIONS.md` §19. Note the unsupported-Xcode upload gate alongside the account/signing blockers — it's a real independent blocker, not just paperwork.
- If posting to LinkedIn, the long-form body reads fine as-is; X should use the short-form and split across 2 posts if needed for length.
