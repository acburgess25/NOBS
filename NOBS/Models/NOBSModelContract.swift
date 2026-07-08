import Foundation

/// Platform-neutral NOBS model request/response contract.
/// Tank and future NOBSbox providers can implement the same shape without Apple types.

struct NOBSModelMessage: Codable, Sendable, Hashable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }

    let role: Role
    let content: String
}

struct NOBSModelContext: Codable, Sendable {
    var userName: String?
    var hasCalendarAccess: Bool
    var agendaSummary: String?
    var tankAvailable: Bool
    var shouldUseTomorrowFraming: Bool
}

enum NOBSModelTask: String, Codable, Sendable {
    case chat
    case briefing
    case summarize
}

struct NOBSModelRequest: Codable, Sendable {
    let messages: [NOBSModelMessage]
    let latestUserMessage: String
    let context: NOBSModelContext
    let task: NOBSModelTask
}

enum NOBSModelRoute: String, Codable, Sendable {
    case onDeviceFoundationModel = "on_device_fm"
    case localRules = "local_rules"
    case tank = "tank"
    case cloud = "nobscloud"

    var displayName: String {
        switch self {
        case .onDeviceFoundationModel:
            "On-device AI"
        case .localRules:
            "Local rules"
        case .tank:
            "Tank"
        case .cloud:
            "NOBScloud"
        }
    }
}

struct NOBSModelPrivacyReceipt: Codable, Sendable, Hashable {
    let used: [String]
    let processed: String
    let shared: [String]
    let changed: [String]
    let dataCategories: [String]

    func appReceipt(routeReason: String, fallbackFrom: NOBSModelRoute?) -> PrivacyReceipt {
        var changedFields = changed
        if let fallbackFrom {
            changedFields.append("Fallback from \(fallbackFrom.displayName)")
        }
        if !routeReason.isEmpty {
            changedFields.append(routeReason)
        }
        return PrivacyReceipt(
            used: used,
            processed: processed,
            shared: shared,
            changed: changedFields
        )
    }
}

struct NOBSModelResponse: Codable, Sendable {
    let text: String
    let route: NOBSModelRoute
    let routeReason: String
    let fallbackFrom: NOBSModelRoute?
    let privacyReceipt: NOBSModelPrivacyReceipt

    var processingRoute: ProcessingRoute {
        switch route {
        case .onDeviceFoundationModel:
            .onDeviceAI
        case .localRules:
            .local
        case .tank:
            .tank
        case .cloud:
            .cloud
        }
    }

    func conversationEntry() -> ConversationEntry {
        ConversationEntry(
            role: .assistant,
            text: text,
            route: processingRoute,
            receipt: privacyReceipt.appReceipt(routeReason: routeReason, fallbackFrom: fallbackFrom)
        )
    }
}
