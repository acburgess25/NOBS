# CI troubleshooting

**Last updated:** August 18, 2026

Quick reference for red checks on NOBS pull requests and `main`.

---

## Check overview

| Check | Workflow | Typical cause | Code fix? |
|-------|----------|---------------|-----------|
| **Any GitHub-hosted job, red in <5s** | Any | Hosted runners cannot be scheduled — billing/quota | **No** — see the section directly below |
| **Python 3.12 on Tank** | Backend CI | Test/lint failure | Yes — run `python3 scripts/dev.py check` |
| **Python 3.12 on Mac runner** | Backend CI | Same | Yes |
| **docs-only-auto-approve** | Auto-approve safe PRs | Stale run on `ubuntu-latest`, or tank runner offline | Re-run after tank workflow on `main`; not an app bug |
| **NOBS \| Default \| Build - iOS** | Xcode Cloud (App Store Connect) | Fails on every PR; redundant with the self-hosted Mac | No — treat as noise, see below |
| **TestFlight** | `.github/workflows/testflight.yml` | Development cert missing on CI keychain; distribution profiles | **Home** — runner + Apple Developer portal. Manual options: refresh signing only, upload staged IPA (`~/nobs-build/NOBS.ipa`), or account cleanup. |
| **NOBSTests** | Backend CI `ios-macos` job | Swift compile or routing fixture drift | Yes — `bash scripts/test-ios.sh` |

---

## Every hosted job fails in seconds (August 2026)

**Symptom.** Every job that runs on a GitHub-hosted runner goes red 1–3 seconds
after it starts. There are no logs to download — the log endpoint returns 404,
because the job never started. Jobs on the self-hosted runners are unaffected
and run normally.

**How to confirm it in one step.** Fetch any failed job and look at the runner
fields:

```bash
# Never scheduled: no runner was ever assigned.
#   "runner_id": 0, "runner_name": "", no "steps"
#
# Compare with a self-hosted job in the same run, which shows:
#   "runner_id": 22, "runner_name": "macbook", with real steps
```

If hosted jobs show `runner_id: 0` **while a self-hosted job in the same
workflow run gets a runner**, the problem is the hosted-runner account state,
not the pull request. No code change will fix it, and re-running will not help.

**Observed on PR #112 (August 18, 2026):** five hosted jobs across two
independent workflows (`Backend CI` and `Auto-approve safe PRs`) all failed
this way, while `NOBSTests on Mac runner` picked up `runner_id: 22` and ran.

**Fix.** Check [Actions billing and spending limits](https://github.com/settings/billing).
The usual cause is the Actions minutes spending cap sitting at zero, not a
declined card — GitHub reports both the same way. Raising the cap makes hosted
jobs schedulable again; the reds clear on the next run.

**Why not just move everything to self-hosted?** `backend-ci.yml` deliberately
uses hosted runners for the Linux/macOS/Windows matrix. That matrix *is* the
cross-platform contract from `docs/AI_WORKFLOW.md` — there is no self-hosted
Windows box, so moving off hosted runners would silently drop Windows coverage
for shared backend code. Fix the billing instead.

**Meanwhile.** The same checks run locally and are the real signal:

```bash
python3 scripts/dev.py check   # tests, lint, formatting
```

---

## docs-only-auto-approve (failure in ~1s, no steps)

**What it is:** Optional bot that auto-approves documentation-only PRs from owners/collaborators. It does **not** run your tests. For mixed PRs (code + docs), it should **pass** with “Not a docs-only PR; no auto-approval needed.”

**Common failure message (often misleading):**

> The job was not started because recent account payments have failed or your spending limit needs to be increased.

**What this usually means (not necessarily a broken credit card):**

- The job **never ran** — zero steps, ~2–4s duration, `runner_id: 0`.
- Inspect the job labels in the Actions UI. If they show **`ubuntu-latest`**, the workflow on **`main` at run time** still targeted GitHub-hosted runners. GitHub often shows the billing/spending-limit message when a hosted job cannot be scheduled — including **Actions minutes spending caps** — even when the payment method is fine.
- **`pull_request_target` always uses the workflow file on `main`**, not the PR branch. A PR that changes `auto-approve.yml` to `self-hosted, tank` does not fix the check until that change is on `main` **and** the workflow is re-run.

**Verified on this repo (July 2026):**

- Failed PR #38 runs: labels `ubuntu-latest`, billing annotation, no steps.
- After `main` switched to `[self-hosted, tank]` (PR #39), PR #41’s `docs-only-auto-approve` **passed in ~30s** on the tank runner — same workflow, no billing issue.

**What to do:**

1. **Re-run** the failed workflow from the PR Checks tab (or push/rebase to trigger a new run). Stale reds from before the tank-runner fix will not clear on their own.
2. Confirm `main` has `runs-on: [self-hosted, tank]` in `.github/workflows/auto-approve.yml`.
3. Confirm the `tank` runner is online: GitHub → Settings → Actions → Runners (Backend CI “Python on Tank” passing is a good signal).
4. Only if **new** runs still target `ubuntu-latest` or hosted runners fail while tank works: check [Actions spending limits](https://github.com/settings/billing) (minutes cap, not always “payment failed”).
5. Optional: remove `docs-only-auto-approve` from **required** branch protection — it is a convenience bot, not a product test.

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

### ⚠️ Every run creates a new distribution certificate

**Check the certificate count before dispatching this workflow.** Observed on the August 14, 2026 `refresh_signing_only` run:

```text
Couldn't find an existing certificate... creating a new one
Successfully generated 6WR47HHPR4
```

`ci-prepare-keychain.sh` builds an empty keychain on every run, so `fastlane cert` never finds the existing certificate's private key and issues a **new** Apple Distribution certificate each time. The standard Apple Developer Program allows **three**. That run took the team from two to three.

**Until August 14, 2026 this had a destructive failure mode.** A failed creation fell through to `ci-revoke-distribution-certs.py`, which revoked **every** distribution certificate on the team. Revocation is not local to CI — it invalidates that certificate everywhere it is installed, including the Xcode install on a developer's own Mac, and it cannot be undone. So a run at the limit destroyed shared signing material to recover a build.

[`ci-ensure-signing-certs.sh`](../scripts/ci-ensure-signing-certs.sh) now fails with instructions instead. Revoking is still available deliberately by running `scripts/ci-revoke-distribution-certs.py` yourself.

**When it fails:**

1. Open Certificates, Identifiers & Profiles → Certificates.
2. Delete surplus **Apple Distribution** certificates, keeping the one in active use.
3. Re-run the workflow.

The certificate count still grows by one per run. The durable fix is for the CI keychain to import an existing distribution certificate — the unused `DIST_CERT_P12` / `DIST_CERT_PASSWORD` secrets exist for exactly this — rather than generating a new one each time. Until that lands, check the count before dispatching.

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
