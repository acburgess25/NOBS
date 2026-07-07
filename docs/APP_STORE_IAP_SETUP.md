# App Store In-App Purchase setup

Use this after the **Paid Applications Agreement** is active in [App Store Connect](https://appstoreconnect.apple.com/).

## Product IDs (must match exactly)

| Product ID | Type | Suggested price | Purpose |
| --- | --- | --- | --- |
| `com.nobsdash.nobs.tip.small` | Consumable | $2.99 | One-time tip |
| `com.nobsdash.nobs.tip.medium` | Consumable | $4.99 | One-time tip |
| `com.nobsdash.nobs.tip.large` | Consumable | $9.99 | One-time tip |
| `com.nobsdash.nobs.nobscloud.monthly` | Auto-renewable subscription | $4.99/mo | NOBScloud early supporter |

Subscription group name: **NOBScloud** (reference in code: `StoreProducts.nobscloudGroupID`).

## App Store Connect checklist

1. **Agreements, Tax, and Banking** — Paid Apps agreement signed; banking and tax complete.
2. **In-App Purchases** → create each product above with matching Product ID.
3. For consumables, set **Cleared for Sale** after metadata review.
4. For NOBScloud, create a subscription group, add the monthly product, set localization and review screenshot if required.
5. **Sandbox tester** — Users and Access → Sandbox → add a test Apple ID.
6. Submit IAP metadata for review with your next app build (or enable for TestFlight internal testing first).

## Local testing in Xcode

1. Open `NOBS.xcodeproj`.
2. Edit the **NOBS** scheme → **Run** → **Options** → **StoreKit Configuration** → select `NOBS/NOBS.storekit`.
3. Run on simulator or device; open **Privacy → Support NOBS** in the app.
4. Purchases use the local StoreKit file without charging real money.

## TestFlight / production

- Remove or override the StoreKit configuration file in the scheme for release archives.
- Test with a **Sandbox Apple ID** on a physical device before going live.
- Tips are consumables — they do not unlock entitlements.
- NOBScloud subscription sets `StoreKitService.hasNOBScloud` when active; cloud features remain **coming soon** until backend entitlement sync ships.

## App Review notes (suggested)

> Tips are optional donations that do not unlock features. NOBScloud is an optional subscription for future cloud capacity. Core local briefing, chat, and Tank pairing remain free. Purchases use Apple In-App Purchase only.

## Privacy policy

Mention Apple processes payments, NOBS does not store card numbers, and tips are not tax-deductible donations unless you operate as a registered nonprofit (adjust wording with your accountant).

See also [`SUPPORT_AND_PAYMENTS.md`](SUPPORT_AND_PAYMENTS.md).
