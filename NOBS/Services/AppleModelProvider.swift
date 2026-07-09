import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleModelKind: Sendable {
    case onDevice
    case pcc
}

struct PCCQuotaStatus: Sendable, Equatable {
    var isLimitReached: Bool = false
    var isApproachingLimit: Bool = false
    var statusMessage: String?

    static let unavailable = PCCQuotaStatus()
}

struct AppleModelAvailability: Sendable {
    var onDeviceAvailable: Bool
    var pccAvailable: Bool
    var pccQuota: PCCQuotaStatus

    static let unavailable = AppleModelAvailability(
        onDeviceAvailable: false,
        pccAvailable: false,
        pccQuota: .unavailable
    )
}

enum AppleModelProviderError: LocalizedError {
    case unavailable(String)
    case quotaLimitReached

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            "Apple model unavailable: \(reason)"
        case .quotaLimitReached:
            "Apple private cloud daily limit reached for today."
        }
    }
}

/// Unified Foundation Models adapter for on-device and Private Cloud Compute routes.
struct AppleModelProvider: Sendable {
    static var availability: AppleModelAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, macOS 27.0, *) {
            return currentAvailability()
        }
        #endif
        return .unavailable
    }

    static var availabilityDescription: String {
        let status = availability
        if status.onDeviceAvailable, status.pccAvailable { return "On-device and Apple Cloud available" }
        if status.onDeviceAvailable { return "On-device model available" }
        if status.pccAvailable { return "Apple Cloud available" }
        return "Apple Intelligence unavailable on this device"
    }

    func respond(
        to message: String,
        kind: AppleModelKind,
        instructions: String = AppleModelProvider.defaultInstructions
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, macOS 27.0, *) {
            return try await respondWithFoundationModels(
                to: message,
                kind: kind,
                instructions: instructions
            )
        }
        #endif
        throw AppleModelProviderError.unavailable("Foundation Models requires iOS 27 or macOS 27.")
    }

    static let defaultInstructions = """
    You are NOBS, a private assistant. Be concise, warm, and plainspoken. \
    If you are not sure about something, say so instead of guessing.
    """

    #if canImport(FoundationModels)
    @available(iOS 27.0, macOS 27.0, *)
    private static func currentAvailability() -> AppleModelAvailability {
        let onDevice: Bool = {
            if case .available = SystemLanguageModel.default.availability { return true }
            return false
        }()

        let pccModel = PrivateCloudComputeLanguageModel()
        let pccAvailable: Bool = {
            if case .available = pccModel.availability { return true }
            return false
        }()

        var quota = PCCQuotaStatus()
        if pccAvailable {
            quota.isLimitReached = pccModel.quotaUsage.isLimitReached
            if case .belowLimit(let info) = pccModel.quotaUsage.status {
                quota.isApproachingLimit = info.isApproachingLimit
            }
            if quota.isLimitReached {
                quota.statusMessage = "Apple private cloud daily limit reached."
            } else if quota.isApproachingLimit {
                quota.statusMessage = "Nearing Apple private cloud daily limit."
            }
        }

        return AppleModelAvailability(
            onDeviceAvailable: onDevice,
            pccAvailable: pccAvailable,
            pccQuota: quota
        )
    }

    @available(iOS 27.0, macOS 27.0, *)
    private func respondWithFoundationModels(
        to message: String,
        kind: AppleModelKind,
        instructions: String
    ) async throws -> String {
        switch kind {
        case .onDevice:
            guard Self.availability.onDeviceAvailable else {
                throw AppleModelProviderError.unavailable(Self.availabilityDescription)
            }
            let session = LanguageModelSession(
                model: .default,
                instructions: instructions
            )
            let response = try await session.respond(to: message)
            return response.content

        case .pcc:
            let pccModel = PrivateCloudComputeLanguageModel()
            guard case .available = pccModel.availability else {
                throw AppleModelProviderError.unavailable("Apple private cloud is not available.")
            }
            if pccModel.quotaUsage.isLimitReached {
                throw AppleModelProviderError.quotaLimitReached
            }
            let session = LanguageModelSession(
                model: pccModel,
                instructions: instructions
            )
            do {
                let response = try await session.respond(to: message)
                return response.content
            } catch {
                if pccModel.quotaUsage.isLimitReached {
                    throw AppleModelProviderError.quotaLimitReached
                }
                throw error
            }
        }
    }

    @available(iOS 27.0, macOS 27.0, *)
    static func showQuotaIncreaseSuggestion() {
        let model = PrivateCloudComputeLanguageModel()
        model.quotaUsage.limitIncreaseSuggestion?.show()
    }
    #endif
}

extension PrivacyReceipt {
    static let applePrivateCloud = PrivacyReceipt(
        used: ["text entered in this conversation"],
        processed: "Apple Private Cloud Compute (not stored after request)",
        shared: [],
        changed: []
    )
}
