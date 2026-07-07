import Foundation

enum ResponseLength: String, Codable, CaseIterable, Sendable {
    case brief
    case standard
    case detailed

    var title: String { rawValue.capitalized }

    var maxListItems: Int {
        switch self {
        case .brief: 3
        case .standard: 6
        case .detailed: 10
        }
    }

    var maxCharacters: Int {
        switch self {
        case .brief: 180
        case .standard: 420
        case .detailed: 900
        }
    }

    var maxWidgetPriorities: Int {
        switch self {
        case .brief: 1
        case .standard: 2
        case .detailed: 3
        }
    }

    var toplineLineLimit: Int {
        switch self {
        case .brief: 2
        case .standard: 2
        case .detailed: 3
        }
    }

    var maxChatSuggestions: Int {
        switch self {
        case .brief: 2
        case .standard: 3
        case .detailed: 3
        }
    }
}

struct BriefingSnapshot: Codable, Sendable {
    var date: String
    var topline: String
    var priorityCount: Int
    var priorities: [String]
    var topPriority: String?
    var hasConflict: Bool
    var conflictSummary: String?
    var route: String
    var generatedAt: Date
    var redactDetailsOnLockScreen: Bool = true
    var responseLength: ResponseLength = .standard
    var eveningHeadline: String?

    static let sample = BriefingSnapshot(
        date: "2026-07-06",
        topline: "A manageable day with one conflict to resolve.",
        priorityCount: 3,
        priorities: ["Team sync at 10:00", "Call plumber"],
        topPriority: "Team sync at 10:00",
        hasConflict: true,
        conflictSummary: "1 overlap needs a decision",
        route: "Local",
        generatedAt: .now,
        responseLength: .standard,
        eveningHeadline: nil
    )

    init(
        date: String,
        topline: String,
        priorityCount: Int,
        priorities: [String],
        topPriority: String?,
        hasConflict: Bool,
        conflictSummary: String?,
        route: String,
        generatedAt: Date,
        redactDetailsOnLockScreen: Bool = true,
        responseLength: ResponseLength = .standard,
        eveningHeadline: String? = nil
    ) {
        self.date = date
        self.topline = topline
        self.priorityCount = priorityCount
        self.priorities = priorities
        self.topPriority = topPriority
        self.hasConflict = hasConflict
        self.conflictSummary = conflictSummary
        self.route = route
        self.generatedAt = generatedAt
        self.redactDetailsOnLockScreen = redactDetailsOnLockScreen
        self.responseLength = responseLength
        self.eveningHeadline = eveningHeadline
    }

    var isStale: Bool {
        generatedAt.timeIntervalSinceNow < -(12 * 60 * 60)
    }

    var showsEveningContext: Bool {
        eveningHeadline != nil || Calendar.current.component(.hour, from: Date()) >= 17
    }

    func shouldRedactDetails(forLockScreen: Bool) -> Bool {
        forLockScreen && redactDetailsOnLockScreen
    }

    func conflictLabel(redacted: Bool) -> String? {
        guard hasConflict else { return nil }
        if redacted {
            return "Schedule conflict"
        }
        return conflictSummary
    }
}
