import Foundation

/// Gates Private Cloud Compute routing and UI until entitlement approval and QA pass.
enum PCCFeatureFlags {
    private static let routingKey = "nobs.pcc.routingEnabled"
    private static let entitledKey = "nobs.pcc.developerEntitled"
    private static let badgeKey = "nobs.pcc.showBadge"

    /// Developer entitlement assigned in the Apple Developer portal.
    static var developerEntitlementConfigured: Bool {
        #if DEBUG
        if UserDefaults.standard.object(forKey: entitledKey) != nil {
            return UserDefaults.standard.bool(forKey: entitledKey)
        }
        #endif
        return (Bundle.main.object(forInfoDictionaryKey: "NOBSPCCEntitlementConfigured") as? Bool) ?? false
    }

    /// Enables PCC in ModelRouter (still subject to runtime availability checks).
    static var routingEnabled: Bool {
        #if DEBUG
        if UserDefaults.standard.object(forKey: routingKey) != nil {
            return UserDefaults.standard.bool(forKey: routingKey)
        }
        #endif
        return (Bundle.main.object(forInfoDictionaryKey: "NOBSPCCRoutingEnabled") as? Bool) ?? false
    }

    /// Shows the Apple Cloud processing badge (honesty gate — off until QA passes).
    static var showBadgeInUI: Bool {
        guard routingEnabled, developerEntitlementConfigured else { return false }
        #if DEBUG
        if UserDefaults.standard.object(forKey: badgeKey) != nil {
            return UserDefaults.standard.bool(forKey: badgeKey)
        }
        #endif
        return (Bundle.main.object(forInfoDictionaryKey: "NOBSPCCShowBadge") as? Bool) ?? false
    }
}
