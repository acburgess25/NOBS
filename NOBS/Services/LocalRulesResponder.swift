import Foundation

enum ProfileMutation: Sendable, Equatable {
    case setFocusPolicies([FocusPolicy])
    case resetFocusPolicies
}

struct LocalRulesOutcome: Sendable {
    let response: NOBSModelResponse
    let profileMutations: [ProfileMutation]
}

struct LocalRulesResponder: Sendable {
    private static let systemFocusIdentifier = "system.focus"

    func respond(to text: String, context: NOBSModelContext) -> LocalRulesOutcome {
        let normalized = text.lowercased()
        var mutations: [ProfileMutation] = []
        let response: String

        if normalized.hasPrefix("remember that") || normalized.hasPrefix("remember:") {
            response = "Memory is stored on Tank. Reconnect in Privacy and say that again, or correct it in Memory once Tank is back."
        } else if normalized.hasPrefix("forget") || normalized.contains("delete memory") {
            response = "Deleting memories requires Tank. Reconnect in Privacy, or remove entries directly from the Memory tab."
        } else if normalized.hasPrefix("actually") || normalized.hasPrefix("correct that") {
            response = "Corrections are saved on Tank. Reconnect in Privacy, or edit the entry in Memory."
        } else if normalized.contains("reset focus") {
            mutations.append(.resetFocusPolicies)
            response = "Focus behavior reset. I'll use standard planning unless you teach me another preference."
        } else if normalized.contains("stay work focused") {
            mutations.append(
                .setFocusPolicies([
                    FocusPolicy(
                        focusIdentifier: Self.systemFocusIdentifier,
                        displayName: "Focus",
                        responseStyle: .concise,
                        allowProactiveNotifications: false,
                        preferredContext: .business
                    ),
                ])
            )
            response = "Got it — I'll stay concise and work-focused while Focus is on."
        } else if normalized.contains("keep personal priority") {
            mutations.append(
                .setFocusPolicies([
                    FocusPolicy(
                        focusIdentifier: Self.systemFocusIdentifier,
                        displayName: "Focus",
                        responseStyle: .standard,
                        allowProactiveNotifications: false,
                        preferredContext: .personal
                    ),
                ])
            )
            response = "Understood — I'll keep personal priorities visible even during Focus."
        } else if normalized.contains("calendar") || normalized.contains("today") || normalized.contains("agenda") {
            if context.hasCalendarAccess, let summary = context.agendaSummary {
                response = summary
            } else {
                response = "I can build that from your real calendar. Open Today and approve Calendar access when you're ready."
            }
        } else if normalized.contains("google") || normalized.contains("alexa") {
            response = "Google Home and Alexa unification is coming soon. Today I can help you design the routine without claiming it has run."
        } else if context.shouldUseTomorrowFraming {
            response = "Tank is unavailable, so I kept this local. We can pick this up tomorrow — open Today if you want to preview the day."
        } else {
            response = "Tank is unavailable, so I kept this request local. I can still help with your calendar and planning; open Privacy to see exactly what was used."
        }

        let used = context.hasCalendarAccess && context.agendaSummary != nil
            ? ["text entered in this conversation", "today's calendar summary"]
            : ["text entered in this conversation"]

        let modelResponse = NOBSModelResponse(
            text: response,
            route: .localRules,
            routeReason: "Tank unavailable — answered with deterministic local rules",
            fallbackFrom: nil,
            privacyReceipt: NOBSModelPrivacyReceipt(
                used: used,
                processed: "Local rules on this iPhone",
                shared: [],
                changed: [],
                dataCategories: ["conversation text"]
            )
        )
        return LocalRulesOutcome(response: modelResponse, profileMutations: mutations)
    }
}
