import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device route backed by the macOS 27 Foundation Models framework.
/// This is the "Local" processing route; Tank remains the preferred route
/// when the local server and Ollama are available.
///
/// Foundation Models ships with the macOS 27 SDK, which today means a beta
/// toolchain. The import is conditional — matching every iOS counterpart — so
/// the same source still compiles against a released toolchain. That build
/// reports the local route as honestly unavailable rather than claiming a
/// model it has no way to reach; Tank remains available either way.
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

    /// Plain-language reason shown in the menu bar when the local route is off.
    static let sdkUnavailableReason =
        "this build was compiled without the Foundation Models SDK"

    static var availabilityDescription: String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            "Available"
        case .unavailable(let reason):
            "Unavailable (\(String(describing: reason)))"
        @unknown default:
            "Unknown"
        }
        #else
        "Unavailable (\(sdkUnavailableReason))"
        #endif
    }

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
        #else
        false
        #endif
    }

    func respond(to message: String) async throws -> String {
        #if canImport(FoundationModels)
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
        #else
        throw LocalRouteError.unavailable(Self.sdkUnavailableReason)
        #endif
    }
}
