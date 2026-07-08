import Foundation

struct BriefingSnapshot: Codable, Sendable {
    var date: String
    var kind: String
    var topline: String
    var priorityCount: Int
    var priorities: [String]
    var topPriority: String?
    var hasConflict: Bool
    var conflictSummary: String?
    var tomorrowPreview: String?
    var unfinishedCount: Int?
    var route: String
    var generatedAt: Date
    var redactDetailsOnLockScreen: Bool = true

    static let sample = BriefingSnapshot(
        date: "2026-07-06",
        kind: BriefingKind.morning.rawValue,
        topline: "A manageable day with one conflict to resolve.",
        priorityCount: 3,
        priorities: ["Team sync at 10:00", "Call plumber"],
        topPriority: "Team sync at 10:00",
        hasConflict: true,
        conflictSummary: "1 overlap needs a decision",
        tomorrowPreview: nil,
        unfinishedCount: nil,
        route: "Local",
        generatedAt: .now
    )

    static let eveningSample = BriefingSnapshot(
        date: "2026-07-06",
        kind: BriefingKind.evening.rawValue,
        topline: "Solid progress today — one item can roll forward without guilt.",
        priorityCount: 2,
        priorities: ["Design sync completed", "Team lunch completed"],
        topPriority: "Design sync completed",
        hasConflict: false,
        conflictSummary: nil,
        tomorrowPreview: "Tomorrow: Standup at 09:00",
        unfinishedCount: 1,
        route: "Local",
        generatedAt: .now
    )

    init(
        date: String,
        kind: String = BriefingKind.morning.rawValue,
        topline: String,
        priorityCount: Int,
        priorities: [String],
        topPriority: String?,
        hasConflict: Bool,
        conflictSummary: String?,
        tomorrowPreview: String? = nil,
        unfinishedCount: Int? = nil,
        route: String,
        generatedAt: Date,
        redactDetailsOnLockScreen: Bool = true
    ) {
        self.date = date
        self.kind = kind
        self.topline = topline
        self.priorityCount = priorityCount
        self.priorities = priorities
        self.topPriority = topPriority
        self.hasConflict = hasConflict
        self.conflictSummary = conflictSummary
        self.tomorrowPreview = tomorrowPreview
        self.unfinishedCount = unfinishedCount
        self.route = route
        self.generatedAt = generatedAt
        self.redactDetailsOnLockScreen = redactDetailsOnLockScreen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? BriefingKind.morning.rawValue
        topline = try container.decode(String.self, forKey: .topline)
        priorityCount = try container.decode(Int.self, forKey: .priorityCount)
        priorities = try container.decode([String].self, forKey: .priorities)
        topPriority = try container.decodeIfPresent(String.self, forKey: .topPriority)
        hasConflict = try container.decode(Bool.self, forKey: .hasConflict)
        conflictSummary = try container.decodeIfPresent(String.self, forKey: .conflictSummary)
        tomorrowPreview = try container.decodeIfPresent(String.self, forKey: .tomorrowPreview)
        unfinishedCount = try container.decodeIfPresent(Int.self, forKey: .unfinishedCount)
        route = try container.decode(String.self, forKey: .route)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        redactDetailsOnLockScreen = try container.decodeIfPresent(Bool.self, forKey: .redactDetailsOnLockScreen) ?? true
    }

    var briefingKind: BriefingKind {
        BriefingKind(rawValue: kind) ?? .morning
    }

    func shouldRedactDetails(forLockScreen: Bool) -> Bool {
        forLockScreen && redactDetailsOnLockScreen
    }

    func conflictLabel(redacted: Bool) -> String? {
        guard hasConflict else { return nil }
        if redacted {
            return briefingKind == .evening ? "Carry-over items" : "Schedule conflict"
        }
        return conflictSummary
    }

    func displayTopline(afterEveningHour hour: Int) -> String {
        if briefingKind == .evening || Calendar.current.component(.hour, from: Date()) >= hour {
            return topline
        }
        return topline
    }
}
