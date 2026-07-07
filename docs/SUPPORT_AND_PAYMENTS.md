# Support and payments

NOBS makes money from **optional capability and services—not personal data** ([`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) §21). Core local features stay free.

This guide covers what you can turn on today versus what ships with the product later.

## Today: donations and sponsorship

Best for build-in-public while the app is still a prototype.

### 1. GitHub Sponsors

1. Enable [GitHub Sponsors](https://github.com/sponsors) on your account.
2. `.github/FUNDING.yml` already points sponsors to `acburgess25`.
3. Add your sponsors URL to `website/public/support.json`:

```json
"githubSponsors": "https://github.com/sponsors/YOUR_HANDLE"
```

### 2. Stripe Payment Links (one-time or monthly)

No backend required. Stripe hosts checkout.

**Quick setup (test mode):**

```bash
export STRIPE_SECRET_KEY=sk_test_…   # Stripe Dashboard → Developers → API keys
python3 scripts/setup_stripe_support_links.py
cd website && pnpm run build
```

Optional amounts (cents): `NOBS_DONATE_ONETIME_CENTS=500`, `NOBS_DONATE_MONTHLY_CENTS=300`.

**Manual setup** in [Stripe Dashboard](https://dashboard.stripe.com/) → **Payment Links** → **New**:
2. Create a **one-time** link for tips (suggested name: “Support NOBS development”).
3. Optionally create a **recurring** link for monthly supporters.
4. Copy each link into `website/public/support.json`:

```json
{
  "githubSponsors": "https://github.com/sponsors/YOUR_HANDLE",
  "donateOneTime": "https://buy.stripe.com/…",
  "donateMonthly": "https://buy.stripe.com/…"
}
```

5. Rebuild and deploy the site, or rsync only `support.json` to Tank if you edit it in place:

```bash
cd website && pnpm run build
rsync -az --delete dist/ tank:~/services/nobsdash/current/
```

The portfolio site shows a **Support** section only when at least one URL is set.

### Tax and compliance

- Stripe and GitHub handle checkout; you are responsible for applicable tax reporting in your jurisdiction.
- Donations are **not** NOBScloud subscriptions and do not unlock in-app paid features.
- Say so clearly on the site (already reflected in the Support copy).

## Later: in-app payments (NOBScloud)

Product requirements ([`PRD.md`](PRD.md) FR-4) call for:

- **StoreKit 2** on iPhone for subscriptions;
- **RevenueCat** (or equivalent) webhooks to sync entitlement;
- Tank API checks before enabling NOBScloud routes.

Planned paid capability (always optional):

- stronger/faster models when Tank is away;
- research and document workflows;
- higher automation limits;
- cross-device continuity.

Do **not** gate today’s free local briefing, widget, or Tank pairing behind a paywall.

## Checklist before going live

- [ ] Stripe account verified and Payment Links tested in test mode, then live mode.
- [ ] GitHub Sponsors profile published.
- [ ] `website/public/support.json` filled in and deployed.
- [ ] Privacy policy mentions payments (processor names, what is not sold).
- [ ] Thank-you page or email configured in Stripe (optional).

## What not to commit

- Stripe secret keys, webhook signing secrets, or live customer data.
- Use Stripe Dashboard and GitHub Secrets for anything server-side when webhooks arrive.
