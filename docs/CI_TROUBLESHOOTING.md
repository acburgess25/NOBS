# CI troubleshooting

**Last updated:** July 7, 2026

Quick reference for red checks on NOBS pull requests and `main`.

---

## Check overview

| Check | Workflow | Typical cause | Code fix? |
|-------|----------|---------------|-----------|
| **Python 3.12 on Tank** | Backend CI | Test/lint failure | Yes — run `python3 scripts/dev.py check` |
| **Python 3.12 on Mac runner** | Backend CI | Same | Yes |
| **docs-only-auto-approve** | Auto-approve safe PRs | Job never started (billing/runner) | Usually **no** — infra/settings |
| **NOBS \| Default \| Build - iOS** | Xcode Cloud (App Store Connect) | Compile or signing on Apple’s builders | Maybe — check ASC build logs |
| **TestFlight** | `.github/workflows/testflight.yml` | Distribution provisioning profiles | **Home** — Apple Developer portal |

---

## docs-only-auto-approve (failure in ~1s, no steps)

**What it is:** Optional bot that auto-approves documentation-only PRs from owners/collaborators. It does **not** run your tests.

**Common failure message:**

> The job was not started because recent account payments have failed or your spending limit needs to be increased.

**What this means:**

- The job never ran — not a Swift/Python bug.
- Historically this happened when the workflow used `ubuntu-latest` (GitHub-hosted minutes). PR #39 moved jobs to the self-hosted `tank` runner.
- `pull_request_target` workflows always read `.github/workflows/auto-approve.yml` from **`main`**, not from the PR branch.

**What to do:**

1. Confirm PR #39+ is on `main` (self-hosted `tank` runners).
2. Verify the `tank` runner is online: GitHub → Settings → Actions → Runners.
3. If still failing with a billing message, check [GitHub Billing & plans](https://github.com/settings/billing) (spending limits, payment method).
4. If the bot cannot approve (GitHub blocks `addPullRequestReview`), manual review is still required — the workflow logs a warning and should not block merge once the runner starts.
5. Optional: remove `docs-only-auto-approve` from **required** branch protection checks if you only want it as a convenience.

---

## TestFlight (main push — Archive failed)

**Latest known error on `main` (July 7, 2026):**

```text
"NOBSWidgets" requires a provisioning profile with the App Groups feature.
"NOBS" requires a provisioning profile with the App Groups and Sign In with Apple features.
```

**What this means:**

- The self-hosted Mac `testflight` runner built the project but **distribution profiles** are missing capabilities:
  - App Group: `group.com.nobsdash.nobs` (app + widget)
  - Sign in with Apple (app only)
- Team: `K853LKQLAS`
- Bundle IDs: `com.nobsdash.nobs`, `com.nobsdash.nobs.widgets`

**What to do (home / Apple Developer):**

1. [Apple Developer](https://developer.apple.com) → Identifiers → confirm App Group + capabilities on both App IDs.
2. Regenerate **Apple Distribution** provisioning profiles for app and widget extension.
3. Ensure CI secrets still match: `DIST_CERT_P12`, `DIST_CERT_PASSWORD`, `ASC_API_KEY_*`.
4. Re-run TestFlight workflow or push to `main` with an iOS path change.
5. Local alternative: `./scripts/stage-testflight-ipa.sh` on a signed Mac.

This is the same class of issue as physical iPhone signing — not fixable from cloud agents without your certificates.

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
```

Fix any failing tests or lint before pushing.

---

## Handoff

When a check’s root cause changes (e.g. provisioning fixed, billing resolved), update this file in the same PR that addresses it.
