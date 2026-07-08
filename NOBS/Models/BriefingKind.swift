import Foundation

enum BriefingKind: String, Codable, Sendable {
    case morning
    case evening

    var title: String {
        switch self {
        case .morning: "Morning briefing"
        case .evening: "Evening wrap-up"
        }
    }

    var systemImage: String {
        switch self {
        case .morning: "sunrise"
        case .evening: "moon.stars"
        }
    }
}
