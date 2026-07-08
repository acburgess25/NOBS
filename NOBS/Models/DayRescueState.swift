import Foundation

struct DayRescueAction: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case chatPrompt(String)
        case resolveOverlap
    }

    let id: String
    let label: String
    let kind: Kind
}

struct DayRescueState: Sendable {
    let explanation: String
    let conflicts: [String]
    let recommendedPlan: [String]
    let actions: [DayRescueAction]
}
