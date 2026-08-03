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

- **GitHub Sponsors** — `.github/FUNDING.yml` and `website/public/support.json` (enable the listing at github.com/sponsors/YOUR_HANDLE; until active the URL may redirect to your profile). Keep the `github:` key in `FUNDING.yml` commented out while `githubSponsors` is empty in `support.json` — a populated `FUNDING.yml` makes GitHub render a native "Sponsor" button on the repo page, so an unenrolled handle there is the same dead-link problem as showing it on the website.
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
