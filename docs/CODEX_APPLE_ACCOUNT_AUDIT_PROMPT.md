# Codex prompt: Apple Developer + Mac audit (NOBS-only)

**Audience:** Paste the block below into Codex on your **home Mac** (needs Xcode, Apple login, and ASC API key access).  
**Goal:** (1) Stop **PosterBoard quit unexpectedly** / simulator wallpaper crash loops, (2) inventory Apple build + App Store Connect state, (3) clean the Developer account so only NOBS remains, (4) report what is healthy vs blocked.  
**Product context:** [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md), [`APP_STORE_BETA_CHECKLIST.md`](APP_STORE_BETA_CHECKLIST.md), [`CODEBASE_REFERENCE.md`](CODEBASE_REFERENCE.md) § Apple Developer / signing, [`CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md) § PosterBoard.

---

## Copy-paste prompt for Codex

```text
You are Codex on my Mac. Do three jobs in order:
(1) Diagnose and fix “PosterBoard quit unexpectedly” / MercuryPosterExtension / ReportCrash spin from the iOS Simulator.
(2) Audit ALL Apple Developer / App Store Connect / local signing state for NOBS.
(3) Clean the Developer account so only NOBS remains (dry-run first).

Use the tools you have (shell, filesystem, Xcode CLIs, simctl, repo scripts, browser/UI automation if available). Do not invent success — report exact command output and blockers.

## Hard constraints
- Repo root: find the NOBS checkout (likely ~/Documents/NOBS or ask `pwd` / search). Work from that root.
- Team ID must be K853LKQLAS.
- KEEP only:
  - Bundle IDs: com.nobsdash.nobs, com.nobsdash.nobs.widgets
  - App Group: group.com.nobsdash.nobs
  - ASC app: NOBS / App Store Connect id 6772071553 (bundle com.nobsdash.nobs)
  - macOS Tank if present: com.nobsdash.nobstank (report it; do not delete unless it is clearly junk — confirm with me before deleting any macOS identifiers)
- NEVER commit secrets, .p8 keys, .p12, provisioning profiles, or .env.
- Destructive Apple cleanup: always dry-run FIRST, show me the KEEP/DELETE list, and wait for my explicit “execute” before --execute or any revoke/delete.
- PosterBoard fixes that erase Simulator data need my OK before `simctl erase` / delete devices; wallpaper-setting and shutting down runaway Simulator are OK without waiting.
- Do not force-push git. Do not change product decisions. Docs updates are OK if you discover durable facts.

## Read first (in repo)
1. docs/CI_TROUBLESHOOTING.md (PosterBoard + TestFlight / signing)
2. docs/APP_STORE_BETA_CHECKLIST.md
3. docs/APP_STORE_IAP_SETUP.md
4. docs/SUPPORT_AND_PAYMENTS.md
5. docs/CODEBASE_REFERENCE.md (Apple Developer / signing state, TestFlight workflow)
6. docs/IOS_SESSION_HANDOFF.md
7. docs/MONETIZATION_AND_GROWTH.md (Phase 0 distribution + IAP)
8. ExportOptions.plist, NOBS/NOBS.storekit, scripts/ci-cleanup-apple-account.py

## Phase 0 — Fix PosterBoard FIRST (do this before long builds)
I keep getting “PosterBoard quit unexpectedly” on this Mac. Treat that as a P0 simulator bug, not a NOBS app bug.

### 0A. Confirm the crash loop
1. Check recent crash reports (do not paste huge binaries; summarize exception + process):
   - `ls -lt ~/Library/Logs/DiagnosticReports/*PosterBoard* 2>/dev/null | head`
   - `ls -lt ~/Library/Logs/DiagnosticReports/*MercuryPoster* 2>/dev/null | head`
   - `ls -lt ~/Library/Logs/DiagnosticReports/*ReportCrash* 2>/dev/null | head`
   - Sample one latest `.ips` / `.crash` for faulting process (PosterBoard / MercuryPosterExtension / PosterKit)
2. CPU spin check:
   - `ps aux | egrep -i 'PosterBoard|MercuryPoster|ReportCrash|Simulator' | grep -v egrep`
   - If ReportCrash or MercuryPosterExtension is pegging CPU, note %CPU
3. List Simulator runtimes/devices:
   - `xcrun simctl list runtimes`
   - `xcrun simctl list devices available`
   - Note which iOS runtime the NOBS scheme uses (prefer iPhone 17 Pro + iOS 27.x per docs)

### 0B. Apply known fixes in order (stop when crash loop stops)
Known cause on recent Xcode / iOS Simulator: missing default wallpaper assets → MercuryPosterExtension / PosterBoard crash-loop → ReportCrash burns CPU. Fix order:

1. **Quit runaway UI noise**
   - Quit Simulator if needed: `killall Simulator 2>/dev/null; killall "iOS Simulator" 2>/dev/null; true`
   - Dismiss stuck Crash Reporter dialogs if present (osascript OK)

2. **Boot the reference simulator and set a wallpaper (primary fix)**
   - Boot: `xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || xcrun simctl boot <best available iPhone UDID>`
   - Open Simulator.app so the UI is visible
   - Inside the simulator: Settings → Wallpaper → pick ANY image → set for **Lock Screen and Home Screen**
     (alternate path that also works: Photos → pick any image → Use as Wallpaper → set both)
   - If UI automation is available, drive those taps; otherwise print exact tap path for me and wait one reply, then re-check CPU
   - Re-check: ReportCrash / MercuryPoster CPU should drop near 0; no new PosterBoard dialogs for ~60s

3. **If still looping: try an older/sibling runtime**
   - Prefer a stable iOS 27.0 (or whatever non-broken runtime is installed) over a broken point release
   - Update scripts/env guidance: `NOBS_SIMULATOR_NAME` / `NOBS_SIMULATOR_OS` and document which pair stopped the crashes
   - Boot that device and set wallpaper there too

4. **If still looping: erase that simulator device (ask me first)**
   - Propose: `xcrun simctl shutdown <udid> && xcrun simctl erase <udid>`
   - After erase: boot again + set wallpaper immediately before unlocking long sessions

5. **Last resorts (ask before destructive)**
   - Delete and re-download the broken Simulator runtime in Xcode → Settings → Platforms
   - `xcrun simctl runtime dyld_shared_cache update --all` (can take a while)
   - Clear Simulator caches only with my OK (`~/Library/Developer/CoreSimulator` is large)

6. **Disable crash dialog spam while developing (optional, ask first)**
   - Only if dialogs keep interrupting after the loop is fixed: explain `defaults write com.apple.CrashReporter DialogType none` and how to restore (`developer` / `basic`). Do not change CrashReporter defaults without my OK.

### 0C. Prove NOBS still builds on the fixed simulator
- `./scripts/build-ios-simulator.sh` (or DEVELOPER_DIR=… xcodebuild with CODE_SIGNING_ALLOWED=NO)
- Prefer the same simulator name/OS that no longer crash-loops
- Record pass/fail

Do not proceed to long ASC cleanup until Phase 0 either is fixed or you have a clear residual-risk note (“dialogs rare / CPU idle”).

## Phase A — Local Mac inventory (read-only)
Run and summarize:

1. Xcode / CLT
   - `xcode-select -p`
   - `ls /Applications | grep -i Xcode`
   - Prefer DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer if present (project expects Xcode 27 beta)
   - `xcodebuild -version` under that DEVELOPER_DIR
   - `xcrun simctl list devices available | head -80`

2. Signing identities & keychains
   - `security find-identity -v -p codesigning`
   - List login + System keychains for Apple Distribution / Apple Development / iPhone Developer leftovers
   - Note expired or duplicate certs

3. DerivedData / local junk (report sizes; only delete with my OK)
   - `du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null`
   - Archives: `ls ~/Library/Developer/Xcode/Archives 2>/dev/null`
   - Provisioning profiles on disk: `ls ~/Library/MobileDevice/Provisioning\ Profiles 2>/dev/null | wc -l`
   - Staged IPA: `ls -la ~/nobs-build 2>/dev/null`
   - Simulator data size: `du -sh ~/Library/Developer/CoreSimulator 2>/dev/null`

4. Project signing settings
   - Grep DEVELOPMENT_TEAM, PRODUCT_BUNDLE_IDENTIFIER, CODE_SIGN_STYLE, APPLICATION_IDENTIFIER in NOBS.xcodeproj and entitlements
   - Confirm App Group group.com.nobsdash.nobs on app + widgets
   - Confirm Sign in with Apple entitlement on main app only

5. ASC API key on disk (existence only — never print key material)
   - Check ~/private_keys/ for AuthKey_*.p8
   - Check env ASC_API_KEY_ID, ASC_API_ISSUER_ID, ASC_API_KEY_PATH
   - If missing, tell me exactly where to create the key in App Store Connect (Users and Access → Integrations → App Store Connect API) with Developer + enough rights for certs/profiles

6. Simulator build (skip if already proven in Phase 0C)
   - `./scripts/build-ios-simulator.sh` OR equivalent xcodebuild with CODE_SIGNING_ALLOWED=NO
   - Record pass/fail

## Phase B — App Store Connect / Developer portal via repo tools
If ASC env + .p8 are available:

1. `python3 scripts/validate-asc-api.py`
2. Inventory (dry-run / list only):
   ```bash
   export ASC_API_KEY_ID=...
   export ASC_API_ISSUER_ID=...
   export ASC_API_KEY_PATH="$HOME/private_keys/AuthKey_${ASC_API_KEY_ID}.p8"
   python3 scripts/ci-cleanup-apple-account.py --list
   python3 scripts/ci-cleanup-apple-account.py   # dry-run cleanup preview
   ```
3. Classify every Bundle ID, certificate, profile, and ASC app as KEEP / DELETE / REVIEW / MANUAL.
4. App Groups are NOT fully API-manageable — open or instruct me to check:
   https://developer.apple.com/account/resources/identifiers/list/applicationGroup
   Keep only group.com.nobsdash.nobs. List any others for manual delete.
5. Identifiers checklist (portal or API):
   - com.nobsdash.nobs: App Groups assigned + Sign in with Apple enabled
   - com.nobsdash.nobs.widgets: App Groups assigned
6. App Store Connect app 6772071553:
   - Agreements: Paid Apps status, tax, banking
   - TestFlight builds present or not
   - IAP products vs docs/APP_STORE_IAP_SETUP.md:
     com.nobsdash.nobs.tip.small / .medium / .large
     com.nobsdash.nobs.nobscloud.monthly
   - Privacy policy URL https://nobsdash.com/privacy.html
7. Certificates: after cleanup we WANT a clean slate then recreate via:
   `bash scripts/refresh-app-store-connect-signing.sh`
   Do NOT run refresh until cleanup dry-run is approved.

If API key is missing: stop Phase B automation; produce a manual portal checklist instead.

## Phase C — Cleanup (ONLY after I type execute)
When I explicitly approve:

1. `python3 scripts/ci-cleanup-apple-account.py --execute`
2. Re-list account; confirm only NOBS bundle IDs remain
3. Manually remind me to delete leftover App Groups in the portal
4. `bash scripts/refresh-app-store-connect-signing.sh` to mint fresh development + distribution certs and profiles
5. Enable capabilities: `python3 scripts/ci-enable-bundle-capabilities.py` (or confirm portal)
6. Try archive path:
   `./scripts/stage-testflight-ipa.sh`
   If it fails, capture the exact signing/capability error and map it to docs/APP_STORE_BETA_CHECKLIST.md § Provisioning

Optional GitHub Actions (self-hosted Mac with testflight label):
- workflow_dispatch TestFlight with refresh_signing_only=true
- or cleanup_apple_account=true ONLY if local --execute already reviewed

## Phase D — “Public Apple things” / career-ready hygiene
1. Confirm nothing in the public git tree looks like a secret (follow docs/PUBLIC_RELEASE.md scan guidance).
2. List what a stranger would see if the repo goes public vs what stays account-private (certs, ASC).
3. Short status for monetization Phase 0: can we take IAP / upload TestFlight yet? Yes/No + next single action.

## Deliverable format
End with a structured report:

### PosterBoard / Simulator
- Crash evidence (process, runtime, CPU before/after)
- Fixes applied (wallpaper / runtime switch / erase / other)
- Stable simulator name + OS for NOBS builds
- Residual risk

### Local Mac
- Xcode path/version, simulator build result, certs found, junk recommended for deletion

### Apple account (NOBS-only)
- Before list (KEEP/DELETE)
- Actions taken (or waiting for execute)
- After list
- Manual portal leftovers (App Groups, agreements, IAP)

### Blockers ordered by severity
1. …
2. …

### Exact next commands for me
Copy-paste commands only — no prose walls.

Start Phase 0 (PosterBoard) now. Then Phase A. Do not --execute Apple cleanup until I say so.
```

---

## Notes for you (human)

1. Run this on the **Mac that has Xcode 27 beta and your Apple ID**, not in a cloud Linux agent.
2. Have App Store Connect API key ready under `~/private_keys/AuthKey_<KEY_ID>.p8` and export the three `ASC_*` vars (or let Codex find them).
3. Say **`execute`** only after you read the KEEP/DELETE list from `ci-cleanup-apple-account.py`.
4. Revoking **all** certificates is intentional in that script’s cleanup path; the refresh script recreates NOBS signing afterward—expect a short window where local/device signing is broken until refresh finishes.
5. **PosterBoard quick fix if you do not want to wait for Codex:** open Simulator → Settings → Wallpaper → set any image for Lock + Home. That usually stops the crash loop within seconds.
