# NOBS Brand & Partner Asset Catalog

Single reference for logos, colors, typography, and store assets used across NOBS (app, website, Tank dashboard, pitch materials).

**Visual board:** open [`brand-logos.html`](brand-logos.html) in a browser for every logo and spec in one place.

---

## NOBS brand

| Asset | Path | Notes |
|-------|------|-------|
| App icon (1024) | `NOBS/Assets.xcassets/AppIcon.appiconset/icon-ios-marketing-1024x1024@1x.png` | App Store / TestFlight |
| Full icon set | `NOBS/Assets.xcassets/AppIcon.appiconset/` | 18 sizes (iPhone + iPad) |
| Icon generator | `scripts/generate_app_icons.py` | Regenerate after art change |
| Design reference | `design/nobs-brand-guide.png` | **Approved logo, icon, colors** |
| Legacy UI reference | `design/nobs-option-3-reference.png` | Earlier UI direction |
| Portfolio reference | `design/nobs-portfolio-workshop-reference.png` | Website visual truth |
| App preview | `website/public/nobs-app-preview.png` | Marketing screenshot |
| Website QA captures | `website/qa-*.png` | Hero, architecture, roadmap |

### Colors

**Canonical source:** [`design/tokens.json`](tokens.json) — shared by iOS (`Color+NOBS.swift`), website (`website/src/nobs-tokens.css`), and icon generator.

| Token | Hex | Use |
|-------|-----|-----|
| Ink | `#172818` | Headlines, primary text |
| Cream | `#F8F6EF` | Canvas / page background |
| Sage | `#5D7D4A` | Secondary accent, status dots |
| Sage dark | `#31562F` | Primary accent, **app icon background** |
| Sage pale | `#E8EDE2` | Cards, subtle surfaces |
| Muted | `#657064` | Body secondary |

App icon: cream **NOBS** serif on **sage-dark** background (matches website workshop palette).

**Legacy:** `design/nobs-brand-guide.png` (alternate palette — superseded by workshop tokens)

### Typography

| Role | Family | Notes |
|------|--------|-------|
| Headlines / logo | Serif (Newsreader in app marketing) | “NOBS” wordmark |
| Body | DM Sans or system sans | UI copy |

### Copy

- **Tagline:** Your technology. Finally working for you.
- **Name:** NOBS — friendly face, “No BS” attitude
- **Bundle ID:** `com.nobsdash.nobs`
- **Marketing version:** 3.0

---

## Partner & platform logos

Use official marks per each vendor’s brand guidelines. The HTML board loads neutral SVG marks from [Simple Icons](https://simpleicons.org/) for reference only — swap for official assets before public marketing.

| Company | Role in NOBS | Official brand resources |
|---------|--------------|--------------------------|
| **Apple** | iOS app, Sign in with Apple, EventKit, Siri/App Intents roadmap | [Apple identity guidelines](https://developer.apple.com/app-store/marketing/guidelines/) |
| **Google** | Future assistant surfaces (product direction) | [Google brand permissions](https://about.google/brand-resource-center/) |
| **Amazon / Alexa** | Future voice surface (product direction) | [Alexa brand guidelines](https://developer.amazon.com/en-US/alexa/branding/alexa-guidelines) |
| **GitHub** | Agent sync, CI, open development | [GitHub logos](https://github.com/logos) |
| **Cloudflare** | `nobsdash` public site tunnel | [Cloudflare brand](https://www.cloudflare.com/trademark/) |
| **Home Assistant** | Smart-home integration (Tank) | [HA branding](https://www.home-assistant.io/branding/) |
| **Ollama** | Local models on Tank | [Ollama GitHub](https://github.com/ollama/ollama) |
| **Ubuntu** | Tank host OS | [Ubuntu brand assets](https://design.ubuntu.com/brand/) |
| **Python / FastAPI** | Tank API backend | [Python logos](https://www.python.org/community/logos/) · [FastAPI](https://fastapi.tiangolo.com/) |

---

## App Store & TestFlight assets

| Asset | Size | Status |
|-------|------|--------|
| App icon | 1024×1024 PNG | ✅ Generated (placeholder “N”) |
| iPhone screenshots | 6.7" (1290×2796), 6.5" (1284×2778), etc. | Use `outputs/device-hub-live-audit/*.png` |
| iPad screenshots | 12.9" (2048×2732) if supporting iPad | `outputs/device-hub-qa/ipad-pro-13.png` |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` | ✅ In `NOBS/Info.plist` |
| Privacy policy URL | Required for external TestFlight | Add before public beta |
| App Store description | — | Draft from `docs/PRODUCT_DECISIONS.md` |

### Current build

- **Version:** 3.0 (11)
- **Team:** K853LKQLAS
- **Distribution profile:** NOBS App Store CI

---

## Tank & dashboard

| Asset | Path |
|-------|------|
| Dashboard UI | `dashboard/` |
| Dashboard QA | `outputs/dashboard-qa/` |
| Kiosk script | `scripts/start-dashboard-kiosk.sh` |

---

## Regeneration commands

```bash
# App icons
python3 scripts/generate_app_icons.py

# Website preview captures (from website/)
pnpm build && pnpm preview
```

---

## Legal note

Third-party logos are trademarks of their owners. Use only in contexts allowed by each vendor’s guidelines. The HTML reference board is for internal product work, not public redistribution of partner marks.
