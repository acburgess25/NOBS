import Foundation

enum TankOfflineBehavior: String, Codable, CaseIterable, Sendable {
    case askEachTime
    case localOnly
    case useAppleCloud
    case useNOBScloud
    case queueForTank

    var title: String {
        switch self {
        case .askEachTime: "Ask each time"
        case .localOnly: "Stay local"
        case .useAppleCloud: "Use Apple private cloud"
        case .useNOBScloud: "Use NOBScloud"
        case .queueForTank: "Wait for Tank"
        }
    }
}

struct RoutingPreferences: Codable, Sendable, Equatable {
    var tankOfflineBehavior: TankOfflineBehavior = .askEachTime
    var allowOneTimeAppleCloud: Bool = false
    var allowOneTimeNOBScloud: Bool = false

    static let `default` = RoutingPreferences()
}

struct RoutingPreferencesStore {
    private static let filename = "routing-preferences.json"

    func load() -> RoutingPreferences {
        (try? AppGroupStore.readJSON(RoutingPreferences.self, from: Self.filename)) ?? .default
    }

    func save(_ preferences: RoutingPreferences) throws {
        try AppGroupStore.writeJSON(preferences, to: Self.filename)
    }
}
