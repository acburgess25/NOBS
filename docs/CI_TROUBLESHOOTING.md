# CI troubleshooting

**Last updated:** August 14, 2026

Quick reference for red checks on NOBS pull requests and `main`.

---

## Check overview

| Check | Workflow | Typical cause | Code fix? |
|-------|----------|---------------|-----------|
| **Python 3.12 on Tank** | Backend CI | Test/lint failure | Yes — run `python3 scripts/dev.py check` |
| **Python 3.12 on Mac runner** | Backend CI | Same | Yes |
| **docs-only-auto-approve** | Auto-approve safe PRs | Stale run on `ubuntu-latest`, or tank runner offline | Re-run after tank workflow on `main`; not an app bug |
| **NOBS \| Default \| Build - iOS** | Xcode Cloud (App Store Connect) | Fails on every PR; redundant with the self-hosted Mac | No — treat as noise, see below |
| **TestFlight** | `.github/workflows/testflight.yml` | Development cert missing on CI keychain; distribution profiles | **Home** — runner + Apple Developer portal. Manual options: refresh signing only, upload staged IPA (`~/nobs-build/NOBS.ipa`), or account cleanup. |
| **NOBSTests** | Backend CI `ios-macos` job | Swift compile or routing fixture drift | Yes — `bash scripts/test-ios.sh` |

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

## Toolchain: why TestFlight is gated, and the Xcode 26.5 route

**The gate.** The Mac runner builds with Xcode-beta 27.0, which is the only Xcode installed on it. App Store Connect rejects uploads built with a beta toolchain, so `testflight.yml` is `workflow_dispatch`-only by design. Xcode 27 was still in beta as of August 2026; the current released toolchain is Xcode 26.5.

**Xcode 27 beta stays the primary development toolchain.** NOBS deliberately builds against the newest Apple frameworks — Foundation Models, Private Cloud Compute, and the rest of the iOS 27 SDK. Nothing below is a reason to stop doing that, and no iOS 27 capability should be removed to make distribution easier.

**The theory worth testing.** The app may not actually *need* the beta SDK to produce a shippable build:

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

**Known trap:** `NOBSTankMac/LocalAssistant.swift` previously imported `FoundationModels` unguarded, unlike every iOS counterpart. That is fixed, and the macOS target is verified to still build under Xcode 27 beta with the guard in place. Watch for the same pattern in new files.

When Xcode 27 reaches a released toolchain, this whole section becomes unnecessary: build everything with it and upload directly.

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
