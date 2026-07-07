import Foundation

enum StoreProducts {
    static let tipSmall = "com.nobsdash.nobs.tip.small"
    static let tipMedium = "com.nobsdash.nobs.tip.medium"
    static let tipLarge = "com.nobsdash.nobs.tip.large"
    static let nobscloudMonthly = "com.nobsdash.nobs.nobscloud.monthly"

    static let tipIDs = [tipSmall, tipMedium, tipLarge]

    static var allIDs: [String] {
        tipIDs + [nobscloudMonthly]
    }

    static let nobscloudGroupID = "nobscloud"
}
