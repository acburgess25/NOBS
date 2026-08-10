# Devlog — NOBScloud's first paid path (built, still gated), Apple-platform audits, and a website that can take money

**Status:** Draft. Plain-language summary of recently merged work, written from `git log` and `docs/CURRENT_STATE.md`. Every claim below is checked against current implementation status — nothing here says a feature is live if it isn't.
**Covers:** roughly the last two weeks of merged PRs on `main` (through `1a5d402`).
**Publish to:** `nobsdash.com` build-in-public log (or GitHub Discussions / a repo `CHANGELOG`-style post) and optionally cross-posted as the "one shipped thing" line in the next X/LinkedIn build note.

## Title options

1. What actually shipped in NOBS this cycle: a paid cloud fallback (built, still gated), Apple-audit agents, and a site that can take money
2. Devlog: NOBScloud's first paid wedge is coded, and the website stops being a brochure

(Pick one when publishing — option 1 is more specific, option 2 is punchier.)

## Body

No BS: this is what actually merged, not what's planned. If you want the roadmap, that's `docs/CURRENT_STATE.md` in the repo — this is the recap in plain language.

### NOBScloud's first real paid path is built — and deliberately still switched off

Up to now, "NOBScloud" was a name on a roadmap. That changed this cycle in code, not yet in production: there's now a real StoreKit 2 subscription and a `ModelRouter` path that, when Tank is unreachable, would route a subscriber's chat through **Apple's Private Cloud Compute** instead of just falling back to on-device processing — gated on the user explicitly telling NOBS cloud processing is okay, with a privacy receipt that says "Apple PCC," not "NOBS's servers," because that's what would actually be happening.

It isn't live yet. The `NOBSPCC*` Info.plist flags that turn routing on are unset and the PCC entitlement isn't in `NOBS.entitlements` — both wait on Apple approving the `com.apple.developer.private-cloud-compute` entitlement and a physical-device QA pass (`docs/PCC_ENTITLEMENT_CHECKLIST.md`). Until then, the honesty gate keeps the Apple Cloud badge hidden and chat stays local — no dead end, no fake spinner, no server that doesn't exist yet.

This is the first Phase 2 monetization wedge described in `docs/MONETIZATION_AND_GROWTH.md`, and it's the reason the in-app Support screen (see below) is worth having at all.

### The in-app Support screen stopped lying when something broke

Small fix, disproportionately important: the Privacy → Support screen used to be able to surface a raw store error to the user if something went wrong. Now it shows an honest, plain-language empty state instead. Boring change, but it's exactly the kind of thing that separates "coming soon" from "coming soon, but also here's a stack trace."

### A rotating cast of research roles, run one shift at a time

`scripts/research_team.py` now hands off between four researcher roles — codebase, psychology/UX, market, and home — instead of one fixed objective every time. Run it and it picks up wherever the rotation left off; force a specific role with `--role`. To be precise about what shipped: it's a manually (or cron-) invoked script that runs **one role per invocation**, not a scheduler running multiple angles concurrently on idle capacity — there's no automatic overnight trigger for it in the repo yet. What it's for is still the point: feed the Research Library described in `docs/PRODUCT_DECISIONS.md` §13 from more than one lens over time instead of the same angle every run.

Also quietly fixed in the same window: web search was failing *silently* — returning empty results without surfacing that anything had gone wrong. That's now a visible failure instead of a quiet one, which matters a lot for something that's supposed to keep working while you're not watching it.

### Apple-platform audits got their own agent system

The repo now ships an "Axiom" agent setup — a set of specialized audit skills for Swift 6 concurrency, SwiftUI, accessibility, memory, and IAP correctness, wired into Claude Code, Cursor, and Codex. This isn't a NOBS product feature; it's tooling for building NOBS itself faster and catching the kind of Apple-platform mistakes (data races, VoiceOver gaps, retain cycles) that are easy to miss by eye. If you're poking around the repo and see `.agents/skills/axiom-*`, that's what it's for — see `docs/AXIOM_AGENTS.md`.

### The website got a real redesign, and a page that can take money

`nobsdash.com` moved off the placeholder look to an editorial, oversized-type, scroll-driven design that actually matches the "Human Companion" brand direction from `docs/PRODUCT_DECISIONS.md` §3 — and it's now built and deployed straight from `main` via GitHub Pages instead of a manual step. Alongside the redesign, the site picked up a real services/support page with a GitHub Sponsors CTA and a live Square one-time tip link — the monthly Square link is still an empty placeholder, but the one-time "send a tip" path actually works today.

### Smaller but worth knowing about

- Swapped `time.monotonic()` for `time.perf_counter()` in the Tank optimizer's API-activity tracking — both are monotonic, so this wasn't fixing a wall-clock bug; it's a higher-resolution clock for the idle-detection timing.
- Added a setup doc for running local inference directly on a Mac, for anyone who wants a Tank-equivalent without a separate Linux box.
- Backend test isolation and Tank auth got hardened so the test suite behaves the same on a fresh checkout as it does on a live, already-configured Tank host.

## What's still not true (say this if anyone asks)

- TestFlight is **not live**. The iPhone app is simulator-verified; physical-device validation and the App Store Connect upload are still pending. The website says "opening soon" because that's accurate.
- The PCC fallback is coded but gated off in production — `NOBSPCCRoutingEnabled` and `NOBSPCCEntitlementConfigured` are unset, and the PCC entitlement itself hasn't been granted by Apple yet. Nobody can actually route through it today. When it does ship, "NOBScloud" will mean Apple's Private Cloud Compute wrapped in an honest label, not a NOBS-operated server fleet — don't let anyone read this as "NOBS now has cloud servers."
- The Square **monthly** support link is still an empty placeholder; only the one-time tip link is live.

## Notes before publishing

- Cross-check `docs/CURRENT_STATE.md` at publish time — if TestFlight has gone live, the PCC flags have been flipped on, or the monthly Square link has been filled in since this was drafted, update the "what's still not true" section before posting anywhere.
- Keep the PCC explanation exactly this precise if reused elsewhere: subscription-gated, on-device entitlement, routes through Apple's infrastructure, not a hosted NOBS backend. Getting this fuzzy is the fastest way to violate the honesty rule in `docs/PRODUCT_DECISIONS.md` §19.
