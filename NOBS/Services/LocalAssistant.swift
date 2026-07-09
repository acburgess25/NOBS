import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// iOS on-device assistant backed by Foundation Models when available.
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
        AppleModelProvider.availabilityDescription
    }

    static var isAvailable: Bool {
        AppleModelProvider.availability.onDeviceAvailable
    }

    func respond(to message: String) async throws -> String {
        try await AppleModelProvider().respond(to: message, kind: .onDevice)
    }
}
