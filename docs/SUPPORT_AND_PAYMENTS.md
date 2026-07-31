# Support and payments

NOBS makes money from **optional capability and services—not personal data** ([`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §21). Core local features stay free.

Operating sequence (tips today → TestFlight → first paid wedge → hardware): [`MONETIZATION_AND_GROWTH.md`](MONETIZATION_AND_GROWTH.md).

## Primary path: Apple In-App Purchase

With the Paid Applications Agreement active, use **StoreKit 2** in the iPhone app:

- **Privacy → Support NOBS** — tip jars (consumables) and NOBScloud monthly subscription
- Local testing: `NOBS/NOBS.storekit` + scheme StoreKit configuration
- Setup checklist: [`APP_STORE_IAP_SETUP.md`](APP_STORE_IAP_SETUP.md)

| Product | ID |
| --- | --- |
| Small tip | `com.nobsdash.nobs.tip.small` |
| Medium tip | `com.nobsdash.nobs.tip.medium` |
| Large tip | `com.nobsdash.nobs.tip.large` |
| NOBScloud monthly | `com.nobsdash.nobs.nobscloud.monthly` |

Tips do not unlock features. NOBScloud subscription unlocks Apple private cloud fallback when Tank is away (on-device StoreKit entitlement + PCC when available). Local briefing and Tank stay free.

## Website and GitHub (optional)

- **GitHub Sponsors** — `.github/FUNDING.yml` and `website/public/support.json`. Enroll first via GitHub → **Your sponsors** (`github.com/sponsors/accounts`): until the profile page actually shows a Sponsor button, leave `githubSponsors` empty in `support.json` so the site doesn't show a dead link (verified `github.com/sponsors/acburgess25` has no Sponsor button as of July 31, 2026).
- **Square Payment Links** — preferred web card tips for NOBS today; not used for in-app digital goods (App Store rules). Create links in the Square Dashboard → Payment Links, then paste into `support.json`.
- **Stripe Payment Links** — still supported if you prefer; helper: `scripts/setup_stripe_support_links.py`. Set `"cardProcessor": "stripe"` so the site labels match.

Edit `website/public/support.json`:

```json
{
  "githubSponsors": "https://github.com/sponsors/YOUR_HANDLE",
  "donateOneTime": "https://square.link/u/…",
  "donateMonthly": "",
  "supportInApp": true,
  "cardProcessor": "square"
}
```

Set `"supportInApp": true` to show that tips and subscriptions also live in the iOS app.

## Later: backend entitlement sync

[`PRD.md`](PRD.md) FR-4 describes RevenueCat webhooks and Tank API checks before enabling multi-device or hosted paid cloud routes. Until then, `hasNOBScloud` is tracked on-device only, and paid fallback runs through Apple PCC on the iPhone.

## Checklist before accepting real money

- [ ] Paid Apps agreement, tax, and banking complete in App Store Connect
- [ ] All four product IDs created and cleared for sale
- [ ] Sandbox purchase tested on a physical iPhone
- [ ] Privacy policy URL lists Apple as payment processor
- [ ] App Review notes explain tips vs subscription vs free tier
