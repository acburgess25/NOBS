# CI troubleshooting

**Last updated:** July 8, 2026

Quick reference for red checks on NOBS pull requests and `main`.

---

## Check overview

| Check | Workflow | Typical cause | Code fix? |
|-------|----------|---------------|-----------|
| **Python 3.12 on Tank** | Backend CI | Test/lint failure | Yes — run `python3 scripts/dev.py check` |
| **Python 3.12 on Mac runner** | Backend CI | Same | Yes |
| **docs-only-auto-approve** | Auto-approve safe PRs | Stale run on `ubuntu-latest`, or tank runner offline | Re-run after tank workflow on `main`; not an app bug |
| **NOBS \| Default \| Build - iOS** | Xcode Cloud (App Store Connect) | Compile or signing on Apple’s builders | Maybe — check ASC build logs |
| **TestFlight** | `.github/workflows/testflight.yml` | Development cert missing on CI keychain; distribution profiles | **Home** — runner + Apple Developer portal |
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

**What this means:**

- The self-hosted Mac `testflight` runner imports an Apple Distribution `.p12`, but `xcodebuild archive` with automatic signing also needs an **Apple Development** certificate whose private key is in the CI keychain.
- A stale Development certificate may exist on the Apple Developer account for this Mac without the matching private key.

**What the workflow does now:**

1. Import distribution `.p12` into an ephemeral CI keychain.
2. Run [`scripts/ci-ensure-signing-certs.sh`](../scripts/ci-ensure-signing-certs.sh) (fastlane `cert`) to create/revoke the Development certificate via the App Store Connect API key.
3. Archive with `CODE_SIGN_IDENTITY` set to the imported Apple Distribution identity.

**If archive still fails:**

1. [Apple Developer](https://developer.apple.com) → Identifiers → confirm App Group + Sign in with Apple on both App IDs.
2. Regenerate **Apple Distribution** provisioning profiles for app and widget extension.
3. Ensure CI secrets match: `DIST_CERT_P12`, `DIST_CERT_PASSWORD`, `ASC_API_KEY_*`.
4. Confirm `fastlane` is installed on the `testflight` runner (`brew install fastlane`).
5. Re-run TestFlight workflow or push to `main` with an iOS path change.
6. Local alternative: `./scripts/stage-testflight-ipa.sh` on a signed Mac.

**Older error (July 7, 2026):**

```text
"NOBSWidgets" requires a provisioning profile with the App Groups feature.
```

Team: `K853LKQLAS` — Bundle IDs: `com.nobsdash.nobs`, `com.nobsdash.nobs.widgets`

---

## NOBS | Default | Build - iOS (Xcode Cloud)

**What it is:** Apple’s Xcode Cloud build attached to the App Store Connect app — separate from GitHub Actions TestFlight.

**When it fails:**

- Open the link in the check → App Store Connect → build logs.
- PR #40 failed here while backend CI passed; PR #38 passed — compare Swift/project changes.
- Common causes: new Swift files not added to `NOBS.xcodeproj`, widget target missing shared sources, signing on Apple’s side.

**Simulator-only validation (no signing):**

```bash
./scripts/build-ios-simulator.sh
```

---

## Backend CI (real code failures)

```bash
python3 scripts/dev.py setup
python3 scripts/dev.py check
bash scripts/test-ios.sh
```

Fix any failing tests or lint before pushing.

---

## Handoff

When a check’s root cause changes (e.g. provisioning fixed, billing resolved), update this file in the same PR that addresses it.
