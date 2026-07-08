import AnyCodable
import Foundation

enum ProcessingRoute: String, Codable, Sendable {
    case local = "Local"
    case onDeviceAI = "On-device AI"
    case tank = "Tank"
    case cloud = "NOBScloud"

    var symbol: String {
        switch self {
        case .tank:
            "server.rack"
        case .onDeviceAI:
            "apple.intelligence"
        case .cloud:
            "cloud"
        case .local:
            "iphone"
        }
    }
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

struct TankMemory: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let content: String
    let category: String
    let source: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, content, category, source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var categoryTitle: String { category.capitalized }

    var sourceTitle: String {
        switch source {
        case "user_explicit": "You said"
        case "briefing": "Briefing"
        default: "Chat"
        }
    }

    var displayDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: updatedAt) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: updatedAt) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
        return updatedAt
    }
}

struct HomeDevice: Identifiable, Codable, Sendable, Hashable {
    let entityId: String
    let name: String
    let state: String
    let domain: String

    var id: String { entityId }

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case name, state, domain
    }

    var domainTitle: String { domain.replacingOccurrences(of: "_", with: " ").capitalized }
}

struct HomeDevicesResponse: Codable, Sendable {
    let configured: Bool
    let devices: [HomeDevice]
    let truncated: Bool
    let message: String?
}

struct ResearchSource: Identifiable, Codable, Sendable, Hashable {
    let title: String
    let url: String
    let kind: String

    var id: String { url }

    var kindTitle: String {
        switch kind {
        case "web_search": "Web"
        case "read_url": "Article"
        case "news_feed": "News"
        default: kind.capitalized
        }
    }
}

struct ResearchJob: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let topic: String
    let context: String
    let status: String
    let summary: String?
    let sources: [ResearchSource]
    let runId: String?
    let createdAt: String
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, topic, context, status, summary, sources
        case runId = "run_id"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }

    var statusTitle: String {
        switch status {
        case "completed": "Ready"
        case "running": "In progress"
        case "awaiting_approval": "Needs approval"
        case "failed": "Failed"
        default: status.capitalized
        }
    }

    var displayDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let raw = completedAt ?? createdAt
        if let date = formatter.date(from: raw) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: raw) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
        return raw
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
    let kind: BriefingKind
    let topline: String
    let priorities: [String]
    let conflictsOrRisks: [String]
    let recommendedPlan: [String]
    let oneUsefulQuestion: String?
    let suggestedNextActions: [String]
    let generatedAt: String
    let route: ProcessingRoute
    let privacyReceipt: PrivacyReceipt
    let clarifyingConflict: ClarifyingConflict?

    enum CodingKeys: String, CodingKey {
        case date, kind, topline, priorities, route
        case conflictsOrRisks = "conflicts_or_risks"
        case recommendedPlan = "recommended_plan"
        case oneUsefulQuestion = "one_useful_question"
        case suggestedNextActions = "suggested_next_actions"
        case generatedAt = "generated_at"
        case privacyReceipt = "privacy_receipt"
        case clarifyingConflict = "clarifying_conflict"
    }

    init(
        date: String,
        kind: BriefingKind = .morning,
        topline: String,
        priorities: [String],
        conflictsOrRisks: [String],
        recommendedPlan: [String],
        oneUsefulQuestion: String?,
        suggestedNextActions: [String],
        generatedAt: String,
        route: ProcessingRoute,
        privacyReceipt: PrivacyReceipt,
        clarifyingConflict: ClarifyingConflict? = nil
    ) {
        self.date = date
        self.kind = kind
        self.topline = topline
        self.priorities = priorities
        self.conflictsOrRisks = conflictsOrRisks
        self.recommendedPlan = recommendedPlan
        self.oneUsefulQuestion = oneUsefulQuestion
        self.suggestedNextActions = suggestedNextActions
        self.generatedAt = generatedAt
        self.route = route
        self.privacyReceipt = privacyReceipt
        self.clarifyingConflict = clarifyingConflict
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        kind = try container.decodeIfPresent(BriefingKind.self, forKey: .kind) ?? .morning
        topline = try container.decode(String.self, forKey: .topline)
        priorities = try container.decode([String].self, forKey: .priorities)
        conflictsOrRisks = try container.decode([String].self, forKey: .conflictsOrRisks)
        recommendedPlan = try container.decode([String].self, forKey: .recommendedPlan)
        oneUsefulQuestion = try container.decodeIfPresent(String.self, forKey: .oneUsefulQuestion)
        suggestedNextActions = try container.decode([String].self, forKey: .suggestedNextActions)
        generatedAt = try container.decode(String.self, forKey: .generatedAt)
        route = try container.decode(ProcessingRoute.self, forKey: .route)
        privacyReceipt = try container.decode(PrivacyReceipt.self, forKey: .privacyReceipt)
        clarifyingConflict = try container.decodeIfPresent(ClarifyingConflict.self, forKey: .clarifyingConflict)
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
    let triggeredBy: String?
    let runObjective: String?
    let runContext: String?
    let auditEvents: [ApprovalAuditEvent]?

    enum CodingKeys: String, CodingKey {
        case id, risk, reason, status, arguments
        case runId = "run_id"
        case toolName = "tool_name"
        case createdAt = "created_at"
        case decidedAt = "decided_at"
        case triggeredBy = "triggered_by"
        case runObjective = "run_objective"
        case runContext = "run_context"
        case auditEvents = "audit_events"
    }
}

struct ApprovalAuditEvent: Identifiable, Codable, @unchecked Sendable {
    let eventType: String
    let detail: [String: AnyCodable]
    let createdAt: String

    var id: String { "\(eventType)|\(createdAt)" }

    enum CodingKeys: String, CodingKey {
        case detail
        case eventType = "event_type"
        case createdAt = "created_at"
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

enum TankSyncStatus: Equatable {
    case unknown
    case connecting
    case connected
    case offline(reason: String)
    case localFallback(pendingMessages: Int)

    var label: String {
        switch self {
        case .unknown:
            return "Checking Tank connection"
        case .connecting:
            return "Reconnecting to Tank"
        case .connected:
            return "Connected on your private network"
        case .offline(let reason):
            return reason
        case .localFallback(let pending):
            if pending > 0 {
                return "Local fallback · \(pending) message\(pending == 1 ? "" : "s") waiting for Tank"
            }
            return "Local fallback — Tank unavailable"
        }
    }

    var symbol: String {
        switch self {
        case .connected:
            return "checkmark.circle.fill"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .offline:
            return "exclamationmark.triangle.fill"
        case .localFallback:
            return "iphone"
        case .unknown:
            return "questionmark.circle"
        }
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
