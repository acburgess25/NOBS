import Foundation

enum NOBSRequestKind: Sendable {
    case chat
    case briefing
}

struct NOBSRequest: Sendable {
    let text: String
    let kind: NOBSRequestKind
    let estimatedTokenCount: Int
    let userRequestedEscalation: Bool
    let userRequestedReasoning: Bool

    static func chat(_ text: String) -> NOBSRequest {
        let normalized = text.lowercased()
        let escalation =
            normalized.contains("think harder")
            || normalized.contains("more reasoning")
            || normalized.contains("use apple cloud")
            || normalized.contains("use private cloud")
        return NOBSRequest(
            text: text,
            kind: .chat,
            estimatedTokenCount: max(1, text.count / 4),
            userRequestedEscalation: escalation,
            userRequestedReasoning: escalation
        )
    }

    static func briefing() -> NOBSRequest {
        NOBSRequest(
            text: "",
            kind: .briefing,
            estimatedTokenCount: 512,
            userRequestedEscalation: false,
            userRequestedReasoning: false
        )
    }

    var fitsOnDeviceContext: Bool {
        estimatedTokenCount < 3_000
    }

    var needsEscalation: Bool {
        userRequestedEscalation || userRequestedReasoning || estimatedTokenCount > 3_000
    }

    var benefitsFromTank: Bool {
        let normalized = text.lowercased()
        return normalized.contains("research")
            || normalized.contains("analyze")
            || normalized.contains("deep")
            || estimatedTokenCount > 2_000
    }
}

enum RoutingReason: String, Codable, Sendable {
    case preferredPrivateCompute
    case onDeviceSufficient
    case reasoningOrContext
    case paidFallback
    case tankOfflinePreference
    case explicitEscalation
    case quotaBlocked
    case templateFallback
    case userPolicy
    case promptRequired
}

struct RoutingDecision: Sendable {
    let route: ProcessingRoute
    let reason: RoutingReason
    let reasonDetail: String?
    let receipt: PrivacyReceipt
    let needsUserPrompt: Bool
    let promptMessage: String?

    init(
        route: ProcessingRoute,
        reason: RoutingReason,
        reasonDetail: String? = nil,
        receipt: PrivacyReceipt,
        needsUserPrompt: Bool = false,
        promptMessage: String? = nil
    ) {
        self.route = route
        self.reason = reason
        self.reasonDetail = reasonDetail
        self.receipt = receipt
        self.needsUserPrompt = needsUserPrompt
        self.promptMessage = promptMessage
    }
}

struct RoutingContext: Sendable {
    let tankAvailable: Bool
    let localFMAvailable: Bool
    let pccAvailable: Bool
    let pccRoutingEnabled: Bool
    let pccQuotaLimitReached: Bool
    let developerEntitled: Bool
    let hasNOBScloud: Bool
    let profile: UserProfile
    let preferences: RoutingPreferences
}

struct ModelRouter: Sendable {
    func route(_ request: NOBSRequest, context: RoutingContext) -> RoutingDecision {
        if context.tankAvailable {
            return tankDecision(request: request)
        }

        if !context.tankAvailable, context.preferences.tankOfflineBehavior == .askEachTime,
           request.kind == .chat, !request.userRequestedEscalation
        {
            return RoutingDecision(
                route: .local,
                reason: .promptRequired,
                receipt: .localOnly,
                needsUserPrompt: true,
                promptMessage: """
                Tank isn't home right now. I can stay local on this iPhone, use Apple's private cloud when you're on an Apple Intelligence device, wait for Tank, or use NOBScloud if you're subscribed.

                Reply with: "stay local", "use apple cloud", "wait for tank", or "use nobscloud".
                """
            )
        }

        switch context.preferences.tankOfflineBehavior {
        case .localOnly:
            return localRouteDecision(context: context, request: request, reason: .tankOfflinePreference)
        case .useAppleCloud:
            if let pcc = pccDecision(context: context, request: request) { return pcc }
            return localRouteDecision(context: context, request: request, reason: .quotaBlocked, detail: "Apple Cloud unavailable; staying local.")
        case .useNOBScloud:
            if let cloud = cloudDecision(context: context, request: request) { return cloud }
            return localRouteDecision(context: context, request: request, reason: .paidFallback, detail: "NOBScloud unavailable; staying local.")
        case .queueForTank:
            return RoutingDecision(
                route: .local,
                reason: .tankOfflinePreference,
                reasonDetail: "Queued for Tank when it returns.",
                receipt: PrivacyReceipt(
                    used: ["text entered in this conversation"],
                    processed: "Local on this iPhone (waiting for Tank)",
                    shared: [],
                    changed: []
                )
            )
        case .askEachTime:
            break
        }

        if context.preferences.allowOneTimeAppleCloud,
           let pcc = pccDecision(context: context, request: request)
        {
            return pcc
        }

        if context.preferences.allowOneTimeNOBScloud,
           let cloud = cloudDecision(context: context, request: request)
        {
            return cloud
        }

        if context.localFMAvailable,
           request.fitsOnDeviceContext,
           !request.userRequestedEscalation
        {
            return RoutingDecision(
                route: .local,
                reason: .onDeviceSufficient,
                receipt: PrivacyReceipt(
                    used: ["text entered in this conversation"],
                    processed: "Local on this iPhone (on-device model)",
                    shared: [],
                    changed: []
                )
            )
        }

        if request.userRequestedEscalation || request.needsEscalation,
           let pcc = pccDecision(context: context, request: request)
        {
            return pcc
        }

        if context.profile.privacyComfort == .cloudOk,
           let cloud = cloudDecision(context: context, request: request)
        {
            return cloud
        }

        if request.userRequestedEscalation,
           context.profile.privacyComfort == .localFirst,
           let pcc = pccDecision(context: context, request: request)
        {
            return pcc
        }

        return localRouteDecision(context: context, request: request, reason: .templateFallback)
    }

    private func tankDecision(request: NOBSRequest) -> RoutingDecision {
        RoutingDecision(
            route: .tank,
            reason: .preferredPrivateCompute,
            receipt: PrivacyReceipt(
                used: ["conversation messages sent with this request"],
                processed: "Tank on your private network",
                shared: [],
                changed: []
            )
        )
    }

    private func localRouteDecision(
        context: RoutingContext,
        request: NOBSRequest,
        reason: RoutingReason,
        detail: String? = nil
    ) -> RoutingDecision {
        let processed = context.localFMAvailable && request.fitsOnDeviceContext
            ? "Local on this iPhone (on-device model)"
            : "Local on this iPhone"
        return RoutingDecision(
            route: .local,
            reason: reason,
            reasonDetail: detail,
            receipt: PrivacyReceipt(
                used: ["text entered in this conversation"],
                processed: processed,
                shared: [],
                changed: []
            )
        )
    }

    private func pccDecision(context: RoutingContext, request: NOBSRequest) -> RoutingDecision? {
        guard context.pccRoutingEnabled,
              context.developerEntitled,
              context.pccAvailable,
              !context.pccQuotaLimitReached
        else { return nil }

        if context.profile.privacyComfort == .localFirst,
           !request.userRequestedEscalation,
           !context.preferences.allowOneTimeAppleCloud
        {
            return nil
        }

        return RoutingDecision(
            route: .pcc,
            reason: request.userRequestedEscalation ? .explicitEscalation : .reasoningOrContext,
            receipt: .applePrivateCloud
        )
    }

    private func cloudDecision(context: RoutingContext, request: NOBSRequest) -> RoutingDecision? {
        guard context.hasNOBScloud, context.profile.privacyComfort == .cloudOk else { return nil }

        // Delivered paid capacity today: Apple Private Cloud Compute under a NOBScloud subscription.
        // Dedicated NOBScloud hosts remain later; do not invent a fake cloud API.
        if context.pccRoutingEnabled,
           context.developerEntitled,
           context.pccAvailable,
           !context.pccQuotaLimitReached
        {
            return RoutingDecision(
                route: .pcc,
                reason: .paidFallback,
                receipt: .nobscloudPaidAppleCloud
            )
        }

        // Subscription is active but Apple Cloud capacity is unavailable on this device/build.
        return RoutingDecision(
            route: .cloud,
            reason: .paidFallback,
            receipt: PrivacyReceipt(
                used: ["conversation messages sent with this request", "NOBScloud subscription"],
                processed: "NOBScloud (Apple Cloud capacity unavailable; staying local)",
                shared: [],
                changed: []
            )
        )
    }
}
