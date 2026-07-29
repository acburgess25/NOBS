# App Store & TestFlight public beta checklist

**Last updated:** July 9, 2026  
**Purpose:** Everything to prepare before you schedule App Review or open a public TestFlight beta.  
**You at home:** signing, archive upload, screenshots from Simulator/device, App Store Connect clicks.

Simulator and cloud agents can complete code, copy, privacy text, and visual polish. **Archive, upload, and review submission require your Mac, Apple Developer account, and working codesigning.**

---

## 1. Apple Developer & App Store Connect (home)

### App record
- [ ] App exists in [App Store Connect](https://appstoreconnect.apple.com) with bundle ID `com.nobsdash.nobs`
- [ ] Widget extension `com.nobsdash.nobs.widgets` registered with same team `K853LKQLAS`
- [ ] App Group `group.com.nobsdash.nobs` enabled on both targets
- [ ] Sign in with Apple capability enabled for the app ID
- [ ] Push Notifications capability **not** required (local notifications only)

### TestFlight build (home)
- [ ] Fix physical-device / distribution signing (widget + app profiles)
- [ ] Archive: `./scripts/stage-testflight-ipa.sh` or Xcode **Product → Archive**
- [ ] Upload IPA or use CI `.github/workflows/testflight.yml` on self-hosted Mac runner
- [ ] Processing completes in App Store Connect (no missing compliance icons)

### Provisioning fix — the actual blocker (clears Xcode Cloud CI *and* device/TestFlight signing)

Symptom: the **`NOBS | Default | Build - iOS`** Xcode Cloud check fails with conclusion `action_required` (~2 min), and local/CI archives fail with *"requires a provisioning profile with the App Groups / Sign In with Apple features."* Root cause is **not code** — the App IDs don't grant the capabilities the project entitlements request.

Reference: team `K853LKQLAS`, app `com.nobsdash.nobs`, widget `com.nobsdash.nobs.widgets`, group `group.com.nobsdash.nobs`, App Store Connect app `6772071553`.

1. [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list):
   - [ ] App Group `group.com.nobsdash.nobs` exists (create it if missing)
   - [ ] `com.nobsdash.nobs` → **App Groups** enabled **and assigned** to that group; **Sign in with Apple** enabled → Save
   - [ ] `com.nobsdash.nobs.widgets` → **App Groups** enabled and assigned to that group → Save
2. Signing is **automatic** (`ExportOptions.plist` → `signingStyle = automatic`), so profiles regenerate on the next build — do not hand-make them:
   - [ ] Xcode Cloud: re-run the failed build in App Store Connect (clears the PR check); approve signing once if prompted
   - [ ] Local: **Product → Archive → Distribute → TestFlight & App Store** (enables the upload)
3. [ ] Confirm the Xcode Cloud check goes green on the re-run — it will **not** clear without a new run *after* step 1

> The Xcode Cloud iOS build is also red on `main`, so until step 1 is done it blocks **every** PR, not just the current one. If a docs/website-only PR needs to merge first, make that check non-required in branch protection temporarily. See [`CI_TROUBLESHOOTING.md`](CI_TROUBLESHOOTING.md).

For a full home-Mac inventory (Xcode, keychains, ASC API, NOBS-only account cleanup dry-run), paste the prompt in [`CODEX_APPLE_ACCOUNT_AUDIT_PROMPT.md`](CODEX_APPLE_ACCOUNT_AUDIT_PROMPT.md) into Codex.

### Export compliance
- [x] `ITSAppUsesNonExemptEncryption = false` in `NOBS/Info.plist` (standard HTTPS only)

---

## 2. Metadata & legal (can prep in repo; paste in ASC at home)

Templates live in [`docs/app-store/`](app-store/).

| Field | Status | Notes |
|-------|--------|-------|
| **Name** | NOBS | 30 chars max |
| **Subtitle** | Private planning on your terms | See `metadata.md` |
| **Description** | Draft in `metadata.md` | Honest prototype boundaries |
| **Keywords** | Draft in `metadata.md` | |
| **Privacy Policy URL** | **Required** | Host `website/public/privacy.html` at `https://nobsdash.com/privacy.html` |
| **Support URL** | `https://nobsdash.com` or GitHub | |
| **Marketing URL** | `https://nobsdash.com` | |
| **Copyright** | © 2026 Alexander Burgess | |
| **Age rating** | 4+ expected | No unrestricted web, no gambling |
| **App Privacy questionnaire** | See `privacy-nutrition.md` | Calendar, Reminders, Device ID (SIWA), optional local network |

### In-app purchases (optional for beta)
- [ ] Create products matching `NOBS/NOBS.storekit` and `StoreProducts.swift`:
  - `com.nobsdash.nobs.tip.small` / `.medium` / `.large` (consumable)
  - `com.nobsdash.nobs.nobscloud.monthly` (subscription, optional)
- [ ] Mark NOBScloud as **coming soon** in review notes if not fully functional

---

## 3. Screenshots & preview (home — Simulator OK)

Capture on **iPhone 17 Pro** (6.9") and optionally iPad if shipping universal.

Recommended frames:
1. **Chat** — personalized greeting, Local badge
2. **Today** — morning briefing with priorities
3. **Today evening** — wrap-up card (set time after 5pm)
4. **Widget** — Home Screen medium widget
5. **Privacy** — processing rules + Tank pairing
6. **Onboarding** — brand + conversational setup

Required sizes (verify in ASC): 6.9", 6.5" iPhone; 13" iPad if iPad supported.

---

## 4. App Review information

See [`docs/app-store/review-notes.md`](app-store/review-notes.md).

- [ ] Demo account **not** required (Sign in with Apple + skip Tank works)
- [ ] Review notes explain Tank is **optional** homelab server; app works locally
- [ ] Notes list Calendar / Reminders / Camera (QR) / Notifications permission timing
- [ ] Contact email and phone for App Review

---

## 5. Code & product honesty (repo — this PR)

- [x] Unified NOBS visual tokens (`Color+NOBS`, `NOBSTheme`, widget uses same palette)
- [x] Beta label in app header
- [x] Coming Soon surfaces styled consistently (Memory, Home)
- [x] Privacy policy draft for hosting
- [ ] Replace hero screenshot on website when you capture a fresh Simulator shot
- [ ] Verify all `TODO(feature)` items are either shipped or honestly labeled coming soon

---

## 6. TestFlight public beta (after first build processes)

- [ ] **Test Information** — beta description + feedback email
- [ ] **Beta App Review** — required for external testers (first build)
- [ ] Create **External Testing** group or open link
- [ ] Add **What to Test** notes (onboarding, Today, widget, optional Tank)

---

## 7. Home-only verification script

```bash
# Signing + archive
./scripts/stage-testflight-ipa.sh

# Or simulator smoke test before archive
./scripts/build-ios-simulator.sh
open NOBS.xcodeproj
```

After upload:
1. Install from TestFlight on a physical iPhone
2. Complete onboarding without Tank
3. Grant Calendar → generate briefing → add widget
4. Optional: pair Tank on home network

---

## 8. What can wait until after beta

- Physical iPhone Tank pairing hardening (mDNS)
- Memory view (still coming soon)
- Home / smart-home unification
- NOBScloud production backend
- Public GitHub repo flip (`docs/PUBLIC_RELEASE.md`)

---

## Handoff

When a step moves from blocked → ready, update this file and [`CURRENT_STATE.md`](CURRENT_STATE.md).
