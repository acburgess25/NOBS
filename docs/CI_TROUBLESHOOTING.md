# CI troubleshooting

**Last updated:** November 25, 2026

Quick reference for red checks on NOBS pull requests and `main`.

---

## Check overview

| Check | Workflow | Typical cause | Code fix? |
|-------|----------|---------------|-----------|
| **Any GitHub-hosted job, red in <5s** | Any | Hosted runners cannot be scheduled — billing/quota hold | **No** — see below |
| **Self-hosted job, cancelled after a long wait, no steps** | Backend CI or TestFlight | The house Mac runner is gone | **No** — re-add the runner, or leave the job skipped |
| **Tests and lint** | Backend CI | Python 3.12 tests or lint on `ubuntu-latest`. This is the gating check. | Yes — `python3 scripts/dev.py check` |
| **Build website** | Website check | Vite build failed. This workflow does not deploy. | Yes — `pnpm install --frozen-lockfile && pnpm build` in `website/` |
| **cross-platform** | Backend CI | Manual dispatch only; never runs on a PR | No — advisory only |
| **NOBS \| Default \| Build - iOS** | Xcode Cloud (App Store Connect) | Fails on every PR; configured outside this repo | No — treat as noise, see below |
| **TestFlight** | `.github/workflows/testflight.yml` | Skipped until `MAC_RUNNER_ONLINE` is `true`. After that: signing on the Mac. | **Home** — runner + Apple Developer portal |
| **NOBSTests on Mac runner** | Backend CI `ios-macos` job | Skipped until `MAC_RUNNER_ONLINE` is `true`. After that: Swift compile or fixture drift. | Yes — `bash scripts/test-ios.sh` on the Mac |

---

## What runs on a pull request

- **Tests and lint** runs on GitHub-hosted `ubuntu-latest` with Python 3.12. It calls `scripts/dev.py setup` and then `scripts/dev.py check`. This is the check that should gate a pull request.
- **Build website** runs on `ubuntu-latest` (Node 22, pnpm 10) and only builds. Deploy stays in `deploy-website.yml`, which was not changed and still publishes on `main`.
- **NOBSTests** and **TestFlight** still target the self-hosted Mac, and they are skipped unless the repository variable `MAC_RUNNER_ONLINE` is exactly `true`. That includes pushes to `main` and manual dispatch, not only pull requests. A missing Mac runner does not fail the job; it leaves it queued with `runner_id` 0 and no steps, which is how pull requests got stuck after the Mac wipe.
- **cross-platform** (Python 3.12 on Linux, macOS, and Windows, plus Python 3.11 on Linux) runs only when someone clicks Run workflow on Backend CI. Linux on Python 3.12 already runs on every pull request via Tests and lint.

Actions → Backend CI → Run workflow has a `runner` input. The default is `ubuntu-latest`. `self-hosted-mac` runs the Python suite on the house Mac. Choose it only when that runner is Idle, or the run waits in the queue.

---

## Every hosted job fails in seconds (`runner_id` 0)

**Symptom.** A job on a GitHub-hosted runner goes red 1–3 seconds after it starts, with no logs (the log endpoint 404s, because the job never ran).

**This is not a bill you owe.** NOBS is a public repository, and GitHub Actions on standard hosted runners is free and unlimited for public repos. The Linux/macOS/Windows matrix ran green and free on August 14, 2026 (run [31831101028](https://github.com/acburgess25/NOBS/actions/runs/31831101028)). Four days later the identical workflow could not get a runner. Nothing about the cost of the repo changed; the account's Actions access did. That hold was still in effect on August 31, 2026, which is why a move to `ubuntu-latest` was reverted the same day it landed. The November 2026 change puts the gating check back on `ubuntu-latest` on purpose, so a pull request shows whether hosted runners work again.

**How to confirm it in one step.** Open the job JSON (the API, or the run page) and look at:

| | Never scheduled | Ran normally |
|---|---|---|
| `runner_id` | `0` | a real id (for example `1000001420` on a hosted runner) |
| `runner_name` | empty | `GitHub Actions 1000001420` |
| `steps` | absent, or empty | present, and they have logs |

A hosted job with `runner_id` 0 and no steps is an account-level Actions problem. No code change fixes it, and re-running will not help until the hold is lifted.

**Fix.** Check [Actions billing and spending limits](https://github.com/settings/billing). On a public repo this is usually a spending cap or an account hold left over from other usage rather than a real charge for this repository. GitHub surfaces all of them with the same "payments have failed or your spending limit needs to be increased" wording.

While that is broken, the Python suite can still be run on your own machine. A red hosted check does not mean the tests failed:

```bash
python3 scripts/dev.py setup
python3 scripts/dev.py check
```

In `website/`:

```bash
pnpm install --frozen-lockfile
pnpm build
```

---

## A self-hosted job sits, then is cancelled (`runner_id` 0)

**Symptom.** The job stays yellow for a long time (often until the 24-hour queue timeout), then shows cancelled. `runner_id` is `0`, `runner_name` is empty, and there are no steps. This is a different failure from the two-second hosted hold above, even though `runner_id` is `0` in both cases. The clock tells them apart: two seconds means GitHub refused to schedule a hosted runner; many hours means nothing with the requested labels was online to pick the job up.

That is what happened after the Mac wipe. Backend CI's tests and NOBSTests both asked for `[self-hosted, macOS, ARM64]`, and no runner has those labels anymore. Example: run [41569182582](https://github.com/acburgess25/NOBS/actions/runs/41569182582) was cancelled a day later with zero steps.

Those jobs are now skipped unless you say the Mac is back. Skipping is a finished result. Queuing is not.

---

## Put the Mac runner back

Do this on the Mac that should build the iPhone app. The Python gating check does not need it.

1. Install Xcode so this path exists: `/Applications/Xcode-beta.app` (the workflows set `DEVELOPER_DIR` there). Install Python 3.11 or newer, ideally Homebrew `python3.12` or `python3.13`.
2. From a checkout of this repo, create a registration token and start the runner:

```bash
export GITHUB_RUNNER_TOKEN="$(gh api repos/acburgess25/NOBS/actions/runners/registration-token -X POST -q .token)"
bash scripts/setup-github-runner-mac.sh
```

The script registers a runner named `macbook` with labels `self-hosted`, `macOS`, `ARM64`, and `testflight`. Token creation needs permission to administer the repository.

3. In GitHub: Settings → Actions → Runners. The runner should show **Idle** with those labels.
4. Settings → Secrets and variables → Actions → Variables. Add a repository variable named `MAC_RUNNER_ONLINE` with the value `true` (lowercase, no quotes).
5. NOBSTests then runs again on pull requests and on pushes to `main`. TestFlight dispatch uses the Mac again. Both stay skipped if the variable is missing or set to anything other than `true`.

To take the Mac offline without deleting it, delete that variable or set it to `false`. Jobs skip instead of queueing.

A one-off Python run on the Mac, without turning NOBSTests back on for every pull request: Actions → Backend CI → Run workflow → `runner` = `self-hosted-mac`. That still queues if the runner is offline, so check that it is Idle first.

---

## Known gap

The check that gates a pull request is Linux only (Python 3.12). macOS and Windows, and the Python 3.11 floor, run when you dispatch Backend CI. iOS tests do not run until the Mac runner is back and `MAC_RUNNER_ONLINE` is `true`. Before merging a change to path handling, process APIs, or file encoding, either dispatch `cross-platform` or run `python3 scripts/dev.py check` on the Tank as well as on the Mac.

**One quirk when changing `pull_request_target` workflows.** That event always runs the copy of the file on `main`, not the copy in the pull request. Deleting or editing one does not change the checks on the pull request making the change. It takes effect after merge. This repo does not currently ship a `pull_request_target` workflow; the note is here because an older docs-only auto-approve workflow did.

**If a removed check name is still required, a pull request can wait forever.** `main` may require a status check by its exact name. The gating job used to be named `Tests and lint (self-hosted Mac)`. It is now `Tests and lint`, and it runs on Ubuntu. A required check that no workflow reports stays pending, and a pull request waiting on it cannot merge — including this one, if the old name is still required. Settings → Branches → `main` → Require status checks, and point the requirement at `Tests and lint` (and `Build website`, if you want the site build to gate too). Remove names no workflow still produces, such as `docs-only-auto-approve`. This change does not edit that setting.

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

**It is also redundant with the Mac jobs, once those jobs are turned back on.** `NOBSTests on Mac runner` (Backend CI `ios-macos`) compiles and tests on the house Mac, and [`testflight.yml`](../.github/workflows/testflight.yml) does the archive, sign, export, and upload through App Store Connect API keys. Both are skipped until the repository variable `MAC_RUNNER_ONLINE` is `true`, because that runner was wiped. Retiring the Xcode Cloud workflow in App Store Connect removes a permanently red check. Until someone does that, treat it as noise — **do not debug a pull request because of it**.

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

## Backend CI and the website (real code failures)

On any machine with Python 3.11 or newer:

```bash
python3 scripts/dev.py setup
python3 scripts/dev.py check
```

The pull-request check uses Python 3.12 on Ubuntu. iOS tests need the Mac and Xcode:

```bash
bash scripts/test-ios.sh
```

Website, from `website/`:

```bash
pnpm install --frozen-lockfile
pnpm build
```

Fix any failing tests, lint, or the site build before pushing. A hosted job that is red in a couple of seconds with no log is the hold described above, not one of these commands.

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
