# Devlog — NOBScloud's first paid path, Apple-platform audits, and a website that can take money

**Status:** Draft. Plain-language summary of recently merged work, written from `git log` and `docs/CURRENT_STATE.md`. Every claim below is checked against current implementation status — nothing here says a feature is live if it isn't.
**Covers:** roughly the last two weeks of merged PRs on `main` (through `1a5d402`).
**Publish to:** `nobsdash.com` build-in-public log (or GitHub Discussions / a repo `CHANGELOG`-style post) and optionally cross-posted as the "one shipped thing" line in the next X/LinkedIn build note.

## Title options

1. What actually shipped in NOBS this cycle: a real paid fallback, Apple-audit agents, and a site that can take money
2. Devlog: NOBScloud gets its first paid wedge, and the website stops being a brochure

(Pick one when publishing — option 1 is more specific, option 2 is punchier.)

## Body

No BS: this is what actually merged, not what's planned. If you want the roadmap, that's `docs/CURRENT_STATE.md` in the repo — this is the recap in plain language.

### NOBScloud has its first real paid path

Up to now, "NOBScloud" was a name on a roadmap. That changed this cycle: when Tank (your home server) is unreachable, a subscriber can now have their chat route through **Apple's Private Cloud Compute** instead of just falling back to on-device processing. It's gated by a real StoreKit 2 subscription, it only kicks in if you've explicitly told NOBS cloud processing is okay, and the privacy receipt is honest about it — it says "Apple PCC," not "NOBS's servers," because that's what's actually happening. There is still no hosted NOBS-run server behind this; that's a deliberate, disclosed limitation, not a bug.

If PCC isn't available for any reason, chat stays local and says so — no dead end, no fake spinner.

This is the first Phase 2 monetization wedge described in `docs/MONETIZATION_AND_GROWTH.md`, and it's the reason the in-app Support screen (see below) is worth having at all.

### The in-app Support screen stopped lying when something broke

Small fix, disproportionately important: the Privacy → Support screen used to be able to surface a raw store error to the user if something went wrong. Now it shows an honest, plain-language empty state instead. Boring change, but it's exactly the kind of thing that separates "coming soon" from "coming soon, but also here's a stack trace."

### The Tank research agent now rotates

Tank's overnight research worker went from a single fixed job to a rotating local research team — multiple angles on a topic get worked on idle capacity instead of one thread doing everything serially. Ties directly into the Research Library described in `docs/PRODUCT_DECISIONS.md` §13: the point was never one summary, it's comparing evidence and keeping disagreements visible instead of smoothing them into false certainty.

Also quietly fixed in the same window: web search was failing *silently* — returning empty results without surfacing that anything had gone wrong. That's now a visible failure instead of a quiet one, which matters a lot for something that's supposed to keep working while you're not watching it.

### Apple-platform audits got their own agent system

The repo now ships an "Axiom" agent setup — a set of specialized audit skills for Swift 6 concurrency, SwiftUI, accessibility, memory, and IAP correctness, wired into Claude Code, Cursor, and Codex. This isn't a NOBS product feature; it's tooling for building NOBS itself faster and catching the kind of Apple-platform mistakes (data races, VoiceOver gaps, retain cycles) that are easy to miss by eye. If you're poking around the repo and see `.agents/skills/axiom-*`, that's what it's for — see `docs/AXIOM_AGENTS.md`.

### The website got a real redesign, and a page that can take money

`nobsdash.com` moved off the placeholder look to an editorial, oversized-type, scroll-driven design that actually matches the "Human Companion" brand direction from `docs/PRODUCT_DECISIONS.md` §3 — and it's now built and deployed straight from `main` via GitHub Pages instead of a manual step. Alongside the redesign, the site picked up a real services/support page wired for Square Payment Links (once the owner fills them in) and a GitHub Sponsors CTA. Nothing is live-charging yet without those links filled in, but the plumbing is real, not a mockup.

### Smaller but worth knowing about

- Fixed a timing bug in API activity tracking (was using wall-clock time in a spot that needed a monotonic clock — `perf_counter` now, so activity durations under load are actually correct instead of occasionally negative or inflated).
- Added a setup doc for running local inference directly on a Mac, for anyone who wants a Tank-equivalent without a separate Linux box.
- Backend test isolation and Tank auth got hardened so the test suite behaves the same on a fresh checkout as it does on a live, already-configured Tank host.

## What's still not true (say this if anyone asks)

- TestFlight is **not live**. The iPhone app is simulator-verified; physical-device validation and the App Store Connect upload are still pending. The website says "opening soon" because that's accurate.
- "NOBScloud" is Apple's Private Cloud Compute wrapped in an honest label, not a NOBS-operated server fleet. Don't let anyone read this as "NOBS now has cloud servers."
- Square Payment Links on the site are still empty placeholders until the owner pastes live Dashboard URLs in.

## Notes before publishing

- Cross-check `docs/CURRENT_STATE.md` at publish time — if TestFlight or Square links have gone live since this was drafted, update the "what's still not true" section before posting anywhere.
- Keep the PCC explanation exactly this precise if reused elsewhere: subscription-gated, on-device entitlement, routes through Apple's infrastructure, not a hosted NOBS backend. Getting this fuzzy is the fastest way to violate the honesty rule in `docs/PRODUCT_DECISIONS.md` §19.
