# Private Cloud Compute — Entitlement Checklist

Complete these steps in App Store Connect and the Apple Developer portal before enabling PCC routing in production builds.

## Developer eligibility (Apple requirements)

1. Enroll in the [App Store Small Business Program](https://developer.apple.com/app-store/small-business-program/).
2. Confirm fewer than **2 million first-time downloads** across all of your App Store apps (App Store Connect → Analytics). TestFlight installs do not count.
3. Request the managed entitlement **`com.apple.developer.private-cloud-compute`** at [developer.apple.com/private-cloud-compute](https://developer.apple.com/private-cloud-compute/).
4. After Apple assigns the entitlement, rebuild with a provisioning profile that includes it.

## Xcode project

- [`NOBS/NOBS.entitlements`](../NOBS/NOBS.entitlements) omits `com.apple.developer.private-cloud-compute` until Apple assigns it — otherwise TestFlight archive fails with “entitlement not found.” Re-add the key after portal approval:
  ```xml
  <key>com.apple.developer.private-cloud-compute</key>
  <true/>
  ```
- Set `NOBSPCCRoutingEnabled` to `YES` in the NOBS target Info.plist only after TestFlight validation on a physical Apple Intelligence device.
- Set `NOBSPCCEntitlementConfigured` to `YES` when the portal entitlement is active.

## Debug toggles (Simulator / development)

In DEBUG builds, UserDefaults keys override plist flags:

| Key | Effect |
|-----|--------|
| `nobs.pcc.routingEnabled` | Enables PCC in the model router |
| `nobs.pcc.developerEntitled` | Simulates entitlement approval |
| `nobs.pcc.showBadge` | Shows Apple Cloud badge in UI (requires routing + entitlement flags) |

## Honesty gate

Do not ship with `NOBSPCCRoutingEnabled` until:

- Entitlement is approved
- Physical-device chat tested on iOS 27+
- [`ModelRouterTests`](../NOBSTests/ModelRouterTests.swift) passing
- Privacy receipts verified in PrivacyView

See [PCC_INTEGRATION.md](PCC_INTEGRATION.md) for the full integration design.
