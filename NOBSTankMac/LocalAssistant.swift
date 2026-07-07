import Foundation
import FoundationModels

/// On-device route backed by the macOS 27 Foundation Models framework.
/// This is the "Local" processing route; Tank remains the preferred route
/// when the local server and Ollama are available.
struct LocalAssistant {
    enum LocalRouteError: LocalizedError {
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason):
                "The on-device model is unavailable: \(reason)"
            }
        }
    }

    static var availabilityDescription: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            "Available"
        case .unavailable(let reason):
            "Unavailable (\(String(describing: reason)))"
        @unknown default:
            "Unknown"
        }
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func respond(to message: String) async throws -> String {
        guard Self.isAvailable else {
            throw LocalRouteError.unavailable(Self.availabilityDescription)
        }
        let session = LanguageModelSession(
            model: .default,
            instructions: """
            You are NOBS, a private assistant running entirely on this Mac. \
            Be concise, warm, and plainspoken. If you are not sure about \
            something, say so instead of guessing.
            """
        )
        let response = try await session.respond(to: message)
        return response.content
    }
}
