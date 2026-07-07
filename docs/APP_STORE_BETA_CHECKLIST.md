# App Store & TestFlight public beta checklist

**Last updated:** July 7, 2026  
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
