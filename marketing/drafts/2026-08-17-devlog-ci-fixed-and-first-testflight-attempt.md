# Devlog — CI stopped lying, a real TestFlight dispatch found two signing bugs, and the site got a new front door

**Status:** Draft. Plain-language summary of recently merged work, written from `git log` and `docs/CURRENT_STATE.md`. Every claim below is checked against current implementation status — nothing here says a feature is live if it isn't.
**Covers:** merged work since the previous devlog draft (`marketing/drafts/2026-08-10-devlog-pcc-fallback-and-axiom-audits.md`), roughly PRs #96–#107 on `main`, through `6d4c278`.
**Publish to:** `nobsdash.com` build-in-public log (or GitHub Discussions / a repo `CHANGELOG`-style post) and optionally cross-posted as the "one shipped thing" line in the next X/LinkedIn build note.

## Title options

1. What actually shipped in NOBS this cycle: CI that isn't permanently red, a live signing dry run, and a landing page with a spine
2. Devlog: we dispatched the real TestFlight pipeline for the first time — and it told us exactly what's still broken

(Pick one when publishing — option 2 is more honest about the headline result: nothing shipped to TestFlight, but the dry run was worth more than another week of code review would have been.)

## Body

No BS: this is what actually merged, not what's planned. If you want the roadmap, that's `docs/CURRENT_STATE.md` in the repo — this is the recap in plain language.

### Every pull request had been red for a reason that had nothing to do with the code

For a while, CI on this repo was structurally unable to pass: every job targeted a self-hosted runner (`tank`) that was no longer registered, so jobs just queued until they were cancelled. A correct, well-tested change and a broken one looked identical in the checks tab. That's now fixed — backend CI runs on GitHub-hosted runners across Python 3.12 on Linux, macOS, and Windows, plus a Python 3.11 run to guard the repo's `>=3.11` floor. That's the actual cross-platform matrix this project has always required in its own contributor rules; Windows had never really been exercised before this. The repo is public, so the runner minutes are free. One thing still deliberately stays on a self-hosted Mac: the SwiftUI test job, because it needs the Xcode 27 beta toolchain that hosted macOS images don't carry, and it simply doesn't run when that Mac is offline.

Related and smaller: a routine dependency bump once turned into 61 CI failures because `pyproject.toml` never pinned an explicit ruff rule set — the enforced rules were just whatever ruff shipped as default, and one ruff release jumped that default from roughly 20 rules to 413. The rule set is now declared explicitly, so a linter upgrade can't silently redefine what "passing" means again. Also closed: an open high-severity dependency advisory on `nanoid` (a transitive dependency of Vite), bumped to the patched version in the website's lockfile.

### Dispatching the real TestFlight pipeline — on purpose, to find what breaks

Rather than keep reading the signing scripts, this cycle actually ran `testflight.yml` against Apple's App Store Connect API in a mode that only refreshes signing material, without attempting a full build. It worked well enough to prove the credentials are good — the API authenticated, listed the app, and provisioned certificates — and in doing so, it surfaced two real bugs that code review alone hadn't caught:

- **A 409 conflict on profile creation.** The cleanup step only deleted the team's existing App Store profiles, but Apple requires profile *names* to be unique across the entire team regardless of type, so a stale profile of a different type blocked creating a new one with the same name.
- **A certificate-revocation footgun.** When creating a new distribution certificate failed — which, it turns out, happens almost every time because the team is already at Apple's certificate limit — the recovery path used to revoke *every* distribution certificate on the team and mint a replacement. Revocation isn't scoped to CI: it invalidates that certificate everywhere it's installed, including someone's own Mac, and it can't be undone. That's a decision for a person, not an automated recovery step. CI now fails with instructions to delete a surplus certificate by hand instead, and revoking anything stays a deliberate, separately-run script.
- **A quieter one in the same run:** the script was picking the first distribution certificate the API returned, which isn't necessarily the one whose private key is actually sitting in the CI keychain — so it could build a profile around a certificate that can't sign anything, and the failure wouldn't show up until archive time, several steps later. Certificate candidates are now matched against what the keychain actually holds, and a run that finds no match at least names the fallback in a warning instead of failing silently downstream.

None of this means TestFlight is closer to live in the "install it today" sense — the underlying blocker (Apple only accepting release-candidate-or-later Xcode builds, and this project developing on an Xcode 27 beta) is unchanged. What changed is that the signing path has now actually been exercised against real Apple infrastructure instead of just read, and it's measurably less likely to fail in a new way the next time someone tries a full archive.

### A written answer to "should this be custom code or a standard?"

New research doc lays out, piece by piece, what in this codebase has no real off-the-shelf equivalent in 2026's self-hosted-assistant landscape (the approval queue, the Personal/Business/Shared context separation, the privacy receipts) versus what's undifferentiated plumbing that should be swapped for an existing standard instead of hand-rolled. First thing it flagged got fixed in the same window: Ollama's chat API accepts a JSON Schema and constrains decoding to match it, so briefing generation now sends the schema it was already validating responses against — instead of asking the model nicely for JSON and hoping. One thing the research got wrong on first pass and corrected after actually building it: the agent's tool-call parser can't be schema-constrained the same way, because that call has to leave room for the model to answer in plain prose instead of calling a tool. A schema controls shape, never whether the model should have been allowed to do something in the first place — that's still the approval queue's job, not the parser's.

### The landing page stopped being a placeholder, and now asks for help specifically

`nobsdash.com`'s front page now leads with a real headline ("Stop renting your AI") and real structure: a Why section, a Status section, a Contribute section, and an honest fine-print section, instead of generic hero copy. Every capability claim on the page carries a plain-text status label next to it — Works today / Built, being verified / Coming soon — not a color-only dot, so the status is legible without relying on color at all. And because the page now explicitly asks for five kinds of contributor help, the repo needed somewhere for that interest to land: it picked up bug/idea/friction issue templates and a real start-here guide, and dropped a leftover DCO sign-off requirement that nothing in the repo's own commit history actually followed — asking newcomers to do something the project itself didn't do.

### Smaller but worth knowing about

- The macOS Tank menu-bar app's on-device model path used to import `FoundationModels` unconditionally, making it the one target that could only ever compile against a beta SDK. It now guards the import the same way every iOS file already does, and reports the local route as honestly unavailable if built without that framework — Tank itself is unaffected either way.
- The toolchain guidance in the docs used to lead with Xcode 26.5 as the practical path, which would have sent a contributor into a second multi-gigabyte toolchain download. It now leads with waiting for the Xcode 27 release candidate (expected early-to-mid September 2026), which needs no code changes and keeps the full iOS 27 SDK; 26.5 is documented as a fallback, not the default.

## What's still not true (say this if anyone asks)

- TestFlight is **not live**. This cycle's signing work found and fixed real bugs in the pipeline, but a full archive-and-upload still hasn't completed successfully. The website correctly still says "opening soon."
- NOBScloud's Apple Private Cloud Compute fallback is coded but still gated off in production, unchanged from last cycle — it's waiting on Apple granting the PCC entitlement and a physical-device QA pass, not on anything this cycle touched.
- The Square **monthly** support link is still an empty placeholder; only the one-time tip link is live.
- GitHub Sponsors is still not enabled — no Sponsor button exists on the profile yet, so the site and README correctly keep that CTA hidden.

## Notes before publishing

- Cross-check `docs/CURRENT_STATE.md` at publish time — if TestFlight has gone live, the PCC flags have been flipped on, or the monthly Square link has been filled in since this was drafted, update the "what's still not true" section before posting anywhere.
- Keep the CI framing precise: the fix is that PRs can now report an accurate pass/fail, not that test coverage itself changed. Don't let "CI is fixed" read as "the app is more tested" — those are different claims.
- Keep the signing-bug framing precise too: describe them as bugs found and fixed in the automation, not as progress toward a specific TestFlight date. No date is scheduled.
