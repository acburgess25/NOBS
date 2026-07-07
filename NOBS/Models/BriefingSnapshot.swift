import Foundation

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

    static let sample = BriefingSnapshot(
        date: "2026-07-06",
        topline: "A manageable day with one conflict to resolve.",
        priorityCount: 3,
        priorities: ["Team sync at 10:00", "Call plumber"],
        topPriority: "Team sync at 10:00",
        hasConflict: true,
        conflictSummary: "1 overlap needs a decision",
        route: "Local",
        generatedAt: .now
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
        redactDetailsOnLockScreen: Bool = true
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
