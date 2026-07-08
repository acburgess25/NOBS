import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelsAdapter {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return availabilityReason() == nil
        }
        #endif
        return false
    }

    static var unavailabilityReason: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return availabilityReason()
        }
        return "Requires iOS 26 or later"
        #else
        return "Foundation Models framework is not linked"
        #endif
    }

    static func generate(request: NOBSModelRequest) async throws -> NOBSModelResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return try await generateWithFoundationModels(request: request)
        }
        #endif
        throw FoundationModelsAdapterError.unavailable(unavailabilityReason ?? "Unavailable")
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func availabilityReason() -> String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device does not support Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off in Settings"
        case .unavailable(.modelNotReady):
            return "On-device model is still downloading"
        case .unavailable:
            return "On-device model is unavailable"
        @unknown default:
            return "On-device model is unavailable"
        }
    }

    @available(iOS 26.0, *)
    private static func generateWithFoundationModels(request: NOBSModelRequest) async throws -> NOBSModelResponse {
        guard availabilityReason() == nil else {
            throw FoundationModelsAdapterError.unavailable(unavailabilityReason ?? "Unavailable")
        }

        let model = SystemLanguageModel.default
        let session = LanguageModelSession(model: model, instructions: systemInstructions(for: request))
        let prompt = userPrompt(for: request)
        let result = try await session.respond(to: prompt)

        let used = dataCategoriesUsed(for: request)
        return NOBSModelResponse(
            text: result.content.trimmingCharacters(in: .whitespacesAndNewlines),
            route: .onDeviceFoundationModel,
            routeReason: "Answered with on-device Foundation Models",
            fallbackFrom: nil,
            privacyReceipt: NOBSModelPrivacyReceipt(
                used: used,
                processed: "On-device AI on this iPhone",
                shared: [],
                changed: [],
                dataCategories: ["conversation text"]
            )
        )
    }

    @available(iOS 26.0, *)
    private static func systemInstructions(for request: NOBSModelRequest) -> String {
        var lines = [
            "You are NOBS, a privacy-first personal assistant.",
            "Tank, the user's home server, is unavailable.",
            "Answer briefly and honestly.",
            "Do not claim to run home automations, send messages, store memories, or access the web.",
            "If you lack context, say so and suggest opening Today or Privacy in NOBS.",
        ]
        if let name = request.context.userName, !name.isEmpty {
            lines.append("The user's name is \(name).")
        }
        if let agenda = request.context.agendaSummary, request.context.hasCalendarAccess {
            lines.append("Calendar summary: \(agenda)")
        }
        return lines.joined(separator: " ")
    }

    @available(iOS 26.0, *)
    private static func userPrompt(for request: NOBSModelRequest) -> String {
        let recent = request.messages.suffix(6).map { message in
            let speaker = message.role == .user ? "User" : "NOBS"
            return "\(speaker): \(message.content)"
        }
        if recent.isEmpty {
            return request.latestUserMessage
        }
        return (recent + ["User: \(request.latestUserMessage)"]).joined(separator: "\n")
    }

    @available(iOS 26.0, *)
    private static func dataCategoriesUsed(for request: NOBSModelRequest) -> [String] {
        var used = ["text entered in this conversation"]
        if request.context.hasCalendarAccess, request.context.agendaSummary != nil {
            used.append("today's calendar summary")
        }
        return used
    }
    #endif
}

enum FoundationModelsAdapterError: Error, Sendable {
    case unavailable(String)
    case generationFailed(String)
}
