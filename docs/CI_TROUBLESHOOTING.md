# CI troubleshooting

**Last updated:** August 18, 2026

Quick reference for red checks on NOBS pull requests and `main`.

---

## Check overview

| Check | Workflow | Typical cause | Code fix? |
|-------|----------|---------------|-----------|
| **Any GitHub-hosted job, red in <5s** | Any | Hosted runners cannot be scheduled — billing/quota | **No** — see the section directly below |
| **Tests and lint (self-hosted Mac)** | Backend CI | Test/lint failure — the gating check | Yes — run `python3 scripts/dev.py check` |
| **cross-platform** | Backend CI | Manual dispatch only; never runs on a PR | No — advisory only |
| **Deploy website / build, deploy** | `deploy-website.yml` | Runs on the self-hosted Mac (since August 20, 2026); fails if that Mac is offline, or on a real `pnpm build` error | Yes if `pnpm build` fails locally in `website/`; otherwise confirm the Mac runner is online |
| **NOBS \| Default \| Build - iOS** | Xcode Cloud (App Store Connect) | Fails on every PR; redundant with the self-hosted Mac | No — treat as noise, see below |
| **TestFlight** | `.github/workflows/testflight.yml` | Development cert missing on CI keychain; distribution profiles | **Home** — runner + Apple Developer portal. Manual options: refresh signing only, upload staged IPA (`~/nobs-build/NOBS.ipa`), or account cleanup. |
| **NOBSTests** | Backend CI `ios-macos` job | Swift compile or routing fixture drift | Yes — `bash scripts/test-ios.sh` |

---

## Every hosted job fails in seconds (August 2026)

**Symptom.** Every job on a GitHub-hosted runner goes red 1–3 seconds after it
starts, with no logs (the log endpoint 404s, because the job never ran). Jobs on
the self-hosted runners are unaffected.

**This is not a bill you owe.** NOBS is a public repository, and GitHub Actions
on standard hosted runners is free and unlimited for public repos. The same
hosted matrix — ubuntu, macOS, and Windows — ran green and free on August 14,
2026 (run 31831101028). Four days later the identical workflow could not get a
runner. Nothing about the cost of the repo changed; the account's Actions
access did.

**How to confirm it in one step.** Look at the runner fields on any failed job:

| | Never scheduled | Ran normally |
|---|---|---|
| `runner_id` | `0` | a real id (e.g. `22`, or `1000001420` for hosted) |
| `runner_name` | empty | `macbook`, `GitHub Actions 1000001420` |
| `steps` | absent | present |

If hosted jobs show `runner_id: 0` while a self-hosted job **in the same
workflow run** gets a runner, the problem is account-level Actions access, not
the pull request. No code change fixes it and re-running will not help.

**Fix.** Check [Actions billing and spending limits](https://github.com/settings/billing).
On a public repo this is usually a spending cap or an account hold left over
from other usage rather than a real charge for this repository — GitHub
surfaces all of them with the same "payments have failed or your spending limit
needs to be increased" wording.

**You are not blocked while it is broken.** Since August 2026 the workflow is
arranged so this cannot stop work:

- `Tests and lint (self-hosted Mac)` is the gating check. It runs on hardware
  in the house, so it costs nothing and does not care about hosted-runner
  availability.
- `cross-platform` (the hosted Linux/macOS/Windows matrix) runs on **manual
  dispatch only**. A job that cannot be scheduled still posts a red X, and a
  red X nobody can act on is worse than no check, so it no longer runs
  automatically. Trigger it from the Actions tab ("Run workflow") when hosted
  runners are working, or before merging a change to path handling, process
  APIs, or file encoding.
- `deploy-website.yml` (`nobsdash.com`, including the `support.json` tip CTA)
  moved to the same self-hosted Mac for the same reason: unlike Backend CI,
  it had no self-hosted fallback, so this outage left the live site stuck on
  a stale build with no code fix able to recover it. It now only needs that
  Mac to be online and have network access — confirm both if a deploy is
  stuck.

The same checks run locally, and that is the real signal either way:

```bash
python3 scripts/dev.py check   # tests, lint, formatting
```

**Known gap, recorded honestly.** The gating check runs on macOS only, so the
cross-platform contract in `docs/AI_WORKFLOW.md` is no longer enforced
automatically. Before merging anything that touches path handling, process
APIs, or file encoding, either dispatch the `cross-platform` job or run
`python3 scripts/dev.py check` on the Tank (Linux). This is a deliberate trade:
a check that always runs and is always free, over one that reports a failure no
diff can fix.

**One quirk when changing `auto-approve`-style workflows.** A
`pull_request_target` workflow always runs the copy of the file on `main`, not
the copy in the pull request. Deleting or editing one does not change the
checks on the pull request making the change — it takes effect after merge.

**If a removed workflow was a required status check, remove it from branch
protection too.** `main` is a protected branch. A required check that no
workflow produces any more never reports, and a pull request waiting on a
check that will never arrive can never merge — including the pull request that
removed the workflow. Settings → Branches → `main` → Require status checks, and
untick anything no workflow still produces (for example
`docs-only-auto-approve`). Do this when merging the change that removes it.

---

## TestFlight (main push — Archive failed)

**Latest known error on `main` (July 2026):**

```text
No signing certificate "iOS Development" found … private key is not installed in your keychain.
```

**What the workflow does now:**

1. Create an ephemeral CI keychain — **no `DIST_CERT_P12` secret**.
2. Provision iPhone Developer + Apple Distribution certificates via App Store Connect API ([`ci-ensure-signing-certs.sh`](../scripts/ci-ensure-signing-certs.sh)).
3. Archive/export with automatic signing and `-allowProvisioningUpdates`.

**Required secrets:** `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`, `ASC_API_KEY_CONTENT` only.

**If archive still fails:**

1. Confirm the three ASC API secrets are set and the key has **Developer** access in App Store Connect.
2. Confirm `fastlane` is on the `testflight` runner (`brew install fastlane`).
3. [Apple Developer](https://developer.apple.com) → Identifiers → App Group + Sign in with Apple on both App IDs.
4. Re-run TestFlight workflow from Actions.

**Older error (July 7, 2026):**

```text
"NOBSWidgets" requires a provisioning profile with the App Groups feature.
```

Team: `K853LKQLAS` — Bundle IDs: `com.nobsdash.nobs`, `com.nobsdash.nobs.widgets`

### ⚠️ A run without the private key creates a new distribution certificate

**Check the certificate count before dispatching this workflow.** Observed on the first August 14, 2026 `refresh_signing_only` run:

```text
Couldn't find an existing certificate... creating a new one
Successfully generated 6WR47HHPR4
```

When the CI keychain has no distribution private key, `fastlane cert` cannot reuse the existing certificate and issues a **new** one. The standard Apple Developer Program allows **three**.

This is not unconditional. A second run the same day reused `6WR47HHPR4` and created nothing, because the key was still in `~/.nobs-ci/signing.keychain-db` from the first run. The risk is therefore concentrated on runs where that keychain is absent or wiped — a rebuilt runner, a cleaned home directory, or a different machine — and each such run costs one certificate slot.

**Until August 14, 2026 this had a destructive failure mode.** A failed creation fell through to `ci-revoke-distribution-certs.py`, which revoked **every** distribution certificate on the team. Revocation is not local to CI — it invalidates that certificate everywhere it is installed, including the Xcode install on a developer's own Mac, and it cannot be undone. So a run at the limit destroyed shared signing material to recover a build.

[`ci-ensure-signing-certs.sh`](../scripts/ci-ensure-signing-certs.sh) now fails with instructions instead. Revoking is still available deliberately by running `scripts/ci-revoke-distribution-certs.py` yourself.

**When it fails:**

1. Open Certificates, Identifiers & Profiles → Certificates.
2. Delete surplus **Apple Distribution** certificates, keeping the one in active use.
3. Re-run the workflow.

The certificate count still grows by one per run. The durable fix is for the CI keychain to import an existing distribution certificate — the unused `DIST_CERT_P12` / `DIST_CERT_PASSWORD` secrets exist for exactly this — rather than generating a new one each time. Until that lands, check the count before dispatching.

### Signing is verified working (August 14, 2026)

A `refresh_signing_only` dispatch on `main` after the two fixes below completed green:

```text
Using distribution certificate 6WR47HHPR4 (Alexander Burgess) — private key present in the signing keychain
Created profile com.nobsdash.nobs AppStore
Created profile com.nobsdash.nobs.widgets AppStore
  App Groups: group.com.nobsdash.nobs
```

Both App Store profiles build, the widget profile carries its App Groups entitlement, and no new certificate was minted. **Certificates, profiles, and the App Store Connect credentials are not blockers.** The only thing standing between this and a TestFlight build is the toolchain gate described below.

Note what the App Group line means: the group existed and was correctly assigned the whole time, while `ci-enable-bundle-capabilities.py` printed "resource ID not found via API" on every run. That message described an unreadable endpoint, not a missing group, and reading it as a finding cost real time. Its wording has been corrected.

### Certificate selection mismatch (fixed)

The same run installed `6WR47HHPR4` into the CI keychain while the profile script embedded a different certificate, `474FC3VL6X`:

```text
Successfully generated 6WR47HHPR4        # imported into the CI keychain
Using distribution certificate 474FC3VL6X # embedded in the profiles
```

`_distribution_certificate_id` took the first Apple Distribution certificate the API returned, which need not be the one whose private key is present. A profile built around an unusable certificate fails at archive time even though every earlier step reports success.

[`ci-create-app-store-profiles.py`](../scripts/ci-create-app-store-profiles.py) now matches candidates against the SHA-1 fingerprints reported by `security find-identity` for the CI keychain, which only lists identities whose private key is installed. If nothing matches it still proceeds, but prints a warning naming the certificate it fell back to — so a mismatch is visible in the log rather than surfacing later as an archive failure.

---

## NOBS | Default | Build - iOS (Xcode Cloud)

**What it is:** Apple’s Xcode Cloud build attached to the App Store Connect app — separate from GitHub Actions TestFlight.

**As of August 14, 2026 it fails on every pull request, including documentation-only ones**, and it is deliberately excluded from required checks. It is configured in App Store Connect rather than in this repository (there is no `ci_scripts/`), so its logs are not reachable from the CLI or `gh`.

**It is also redundant.** Everything it would do already runs on the self-hosted Mac: `NOBSTests on Mac runner` (Backend CI `ios-macos`) compiles and tests on every pull request and *is* a required check, and [`testflight.yml`](../.github/workflows/testflight.yml) does the full archive → sign → export → upload locally through App Store Connect API keys. Retiring the Xcode Cloud workflow in App Store Connect removes a permanently red check without losing coverage. Until someone does that, treat it as noise — **do not debug a pull request because of it**.

**When it fails:**

- Open the link in the check → App Store Connect → build logs.
- Common causes: new Swift files not added to `NOBS.xcodeproj`, widget target missing shared sources, signing on Apple’s side.

**Simulator-only validation (no signing):**

```bash
./scripts/build-ios-simulator.sh
```

---

## Toolchain: why TestFlight is gated

**The gate.** The Mac runner builds with Xcode-beta 27.0, the only Xcode installed on it. App Store Connect rejects uploads built with a beta toolchain, so `testflight.yml` is `workflow_dispatch`-only by design. As of August 2026 Xcode 27 is still beta; the released toolchain is Xcode 26.5, and Apple has required Xcode 26 or later with current platform SDKs since April 28, 2026.

**Xcode 27 beta stays the primary development toolchain.** NOBS deliberately builds against the newest Apple frameworks — Foundation Models, Private Cloud Compute, and the rest of the iOS 27 SDK. Nothing here is a reason to stop doing that, and no iOS 27 capability should be removed to make distribution easier.

### Recommended: wait for the Xcode 27 release candidate

App Store Connect accepts RC-built uploads. iOS 27's RC is expected in **early-to-mid September 2026** (third-party prediction, not an Apple announcement — Apple confirms at its September event), with general release shortly after. Building with the Xcode 27 RC ships the **full iOS 27 SDK compiled in**, needs no second toolchain, and requires no code changes. That is the intended path.

The wait costs nothing on the critical path, because the two things that must happen before a TestFlight build is useful are **not** toolchain-gated:

- **Physical iPhone validation needs no upload at all.** Build and run on a device straight from Xcode 27 beta with a development profile. This is a TestFlight prerequisite and can be done today.
- **The PCC entitlement is still pending Apple's approval** (`docs/PCC_ENTITLEMENT_CHECKLIST.md`), independent of any toolchain.

External TestFlight also requires beta review, which is its own queue after upload.

### Fallback only: the Xcode 26.5 route

Use this **only** if the RC slips or a build must ship before it lands. It costs a second multi-gigabyte Xcode install and produces an artifact with Foundation Models compiled out. It is not the default and should not be set up on spec.

The app may not actually *need* the beta SDK to produce a shippable build:

- `IPHONEOS_DEPLOYMENT_TARGET` is **18.0**, not 27.
- Every `import FoundationModels` in the iPhone app is wrapped in `#if canImport(FoundationModels)`, and iOS 27 APIs sit behind `@available(iOS 27.0, *)` guards.
- Apple Cloud / PCC routing is already gated off in production (`NOBSPCC*` flags unset, entitlement not granted), so a build compiled without that SDK loses nothing a user can reach today.

If that holds, installing **Xcode 26.5 alongside** the beta produces an upload App Store Connect accepts, with the iOS 27 features compiled out of that artifact only. The beta toolchain keeps building the full-featured app for development and simulator work. One source tree, two toolchains — which is what the `canImport` guards are for.

**This is unverified.** It has not been compiled against 26.5. To test it:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project NOBS.xcodeproj -scheme NOBS \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

**What would disprove it:** any compile error naming an iOS 27 symbol *outside* a `canImport`/`@available` guard. Fix by adding the guard, not by lowering ambition — the feature should still compile and run under the beta toolchain.

### Keep the guards intact either way

`NOBSTankMac/LocalAssistant.swift` previously imported `FoundationModels` unguarded, unlike every iOS counterpart, which made it the one file that could only ever compile against a beta SDK. That is fixed, and the macOS target is verified to still build under Xcode 27 beta with the guard in place. Watch for the same pattern in new files — the guards cost nothing under the beta toolchain and are what keep the fallback available.

Once Xcode 27 ships as an RC or release, the fallback section above stops mattering: build everything with it and upload directly.

---

## Backend CI (real code failures)

```bash
python3 scripts/dev.py setup
python3 scripts/dev.py check
bash scripts/test-ios.sh
```

Fix any failing tests or lint before pushing.

---

## PosterBoard quit unexpectedly (local Mac / Simulator)

**What it is:** macOS dialog spam from the **iOS Simulator** lock-screen / wallpaper stack (`PosterBoard`, often `MercuryPosterExtension`), not a NOBS app crash. Common on recent Xcode betas when a Simulator runtime ships without usable default wallpaper assets; `ReportCrash` may peg CPU.

**Fast fix**

1. Boot the simulator you use for NOBS (usually iPhone 17 Pro).
2. In the simulator: **Settings → Wallpaper** (or Photos → Use as Wallpaper) and set **any** image for Lock Screen **and** Home Screen.
3. Confirm `ReportCrash` / `MercuryPosterExtension` CPU drops in Activity Monitor within ~a minute.

**If it keeps looping**

- Try a sibling runtime (e.g. iOS 27.0 instead of a broken point release) via `NOBS_SIMULATOR_OS` / scheme destination.
- Erase that simulator device (`xcrun simctl erase <udid>`), boot, and set wallpaper immediately.
- Re-download the Simulator runtime in Xcode → Settings → Platforms.

Full Mac audit (PosterBoard + Apple account cleanup): paste [`CODEX_APPLE_ACCOUNT_AUDIT_PROMPT.md`](CODEX_APPLE_ACCOUNT_AUDIT_PROMPT.md) into Codex on the home Mac.

---

## Handoff

When a check’s root cause changes (e.g. provisioning fixed, billing resolved), update this file in the same PR that addresses it.
