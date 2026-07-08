import Foundation

@MainActor
final class LocalChatRouter {
    private let rulesResponder = LocalRulesResponder()

    func respond(
        to text: String,
        conversation: [ConversationEntry],
        context: NOBSModelContext
    ) async -> (entry: ConversationEntry, profileMutations: [ProfileMutation]) {
        let request = Self.buildRequest(
            text: text,
            conversation: conversation,
            context: context
        )

        if FoundationModelsAdapter.isAvailable {
            do {
                let response = try await FoundationModelsAdapter.generate(request: request)
                return (response.conversationEntry(), [])
            } catch {
                let reason: String
                if case FoundationModelsAdapterError.unavailable(let detail) = error {
                    reason = detail
                } else {
                    reason = error.localizedDescription
                }
                return rulesFallback(
                    request: request,
                    fallbackFrom: .onDeviceFoundationModel,
                    reason: "Foundation Models unavailable (\(reason))"
                )
            }
        }

        let reason = FoundationModelsAdapter.unavailabilityReason ?? "Foundation Models unavailable"
        return rulesFallback(
            request: request,
            fallbackFrom: .onDeviceFoundationModel,
            reason: reason
        )
    }

    private func rulesFallback(
        request: NOBSModelRequest,
        fallbackFrom: NOBSModelRoute,
        reason: String
    ) -> (entry: ConversationEntry, profileMutations: [ProfileMutation]) {
        let outcome = rulesResponder.respond(to: request.latestUserMessage, context: request.context)
        let adjusted = NOBSModelResponse(
            text: outcome.response.text,
            route: .localRules,
            routeReason: reason,
            fallbackFrom: fallbackFrom,
            privacyReceipt: outcome.response.privacyReceipt
        )
        return (adjusted.conversationEntry(), outcome.profileMutations)
    }

    private static func buildRequest(
        text: String,
        conversation: [ConversationEntry],
        context: NOBSModelContext
    ) -> NOBSModelRequest {
        let messages = conversation.map { entry in
            NOBSModelMessage(
                role: entry.role == .user ? .user : .assistant,
                content: entry.text
            )
        }
        return NOBSModelRequest(
            messages: messages,
            latestUserMessage: text,
            context: context,
            task: .chat
        )
    }
}
