import AnyCodable
import Foundation

enum ProcessingRoute: String, Codable, Sendable {
    case local = "Local"
    case tank = "Tank"
    case cloud = "NOBScloud"
}

struct PrivacyReceipt: Codable, Hashable, Sendable {
    let used: [String]
    let processed: String
    let shared: [String]
    let changed: [String]

    static let localOnly = PrivacyReceipt(
        used: ["text entered in this conversation"],
        processed: "Local on this iPhone",
        shared: [],
        changed: []
    )
}

struct ConversationEntry: Identifiable, Codable, Sendable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    let route: ProcessingRoute?
    let receipt: PrivacyReceipt?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        route: ProcessingRoute? = nil,
        receipt: PrivacyReceipt? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.route = route
        self.receipt = receipt
    }
}

struct DayEvent: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let calendarName: String
    let context: BriefingContextBucket

    var overlapsNext: Bool = false
}

enum BriefingContextBucket: String, Codable, CaseIterable {
    case personal
    case business
    case shared

    var title: String { rawValue.capitalized }
}

struct DayReminder: Identifiable, Hashable {
    let id: String
    let title: String
    let due: Date?
    let calendarName: String
    let context: BriefingContextBucket
}

struct TankSchedule: Identifiable, Codable, Sendable {
    let id: String
    let timeOfDay: String
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case timeOfDay = "time_of_day"
        case createdAt = "created_at"
    }
}

struct SyncActivityEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let route: ProcessingRoute
    let receipt: PrivacyReceipt
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        route: ProcessingRoute,
        receipt: PrivacyReceipt,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.route = route
        self.receipt = receipt
        self.createdAt = createdAt
    }
}

struct DailyBriefing: Codable, Sendable {
    let date: String
    let topline: String
    let priorities: [String]
    let conflictsOrRisks: [String]
    let recommendedPlan: [String]
    let oneUsefulQuestion: String?
    let suggestedNextActions: [String]
    let generatedAt: String
    let route: ProcessingRoute
    let privacyReceipt: PrivacyReceipt

    enum CodingKeys: String, CodingKey {
        case date, topline, priorities, route
        case conflictsOrRisks = "conflicts_or_risks"
        case recommendedPlan = "recommended_plan"
        case oneUsefulQuestion = "one_useful_question"
        case suggestedNextActions = "suggested_next_actions"
        case generatedAt = "generated_at"
        case privacyReceipt = "privacy_receipt"
    }
}

struct PendingApproval: Identifiable, Codable, @unchecked Sendable {
    let id: String
    let runId: String
    let toolName: String
    let arguments: [String: AnyCodable]
    let risk: String
    let reason: String
    let status: String
    let createdAt: String
    let decidedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, risk, reason, status, arguments
        case runId = "run_id"
        case toolName = "tool_name"
        case createdAt = "created_at"
        case decidedAt = "decided_at"
    }
}

struct AgentProposal: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let description: String
    let proposalType: String
    let status: String
    let createdAt: String
    let decidedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, status
        case proposalType = "proposal_type"
        case createdAt = "created_at"
        case decidedAt = "decided_at"
    }
}

enum TankFetchState: Equatable {
    case idle
    case loading
    case loaded
    case unavailable
    case failed(String)

    var errorMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case today = "Today"
    case approvals = "Approvals"
    case memory = "Memory"
    case activity = "Activity"
    case home = "Home"
    case privacy = "Privacy"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .chat: "message"
        case .today: "sun.max"
        case .approvals: "checkmark.shield"
        case .memory: "brain"
        case .activity: "clock.arrow.circlepath"
        case .home: "house"
        case .privacy: "hand.raised"
        }
    }
}

extension AnyCodable {
    var displayString: String {
        switch value {
        case let value as String:
            return value
        case let value as Bool:
            return value ? "true" : "false"
        case let value as Int:
            return "\(value)"
        case let value as Double:
            return "\(value)"
        default:
            return String(describing: value)
        }
    }
}

extension PrivacyReceipt: Identifiable {
    var id: String {
        "\(processed)|\(used.joined(separator: ","))|\(shared.joined(separator: ","))|\(changed.joined(separator: ","))"
    }
}
