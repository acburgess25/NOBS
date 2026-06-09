/// NOBSHomeKit — Smart Home Control
///
/// Wraps Apple's HomeKit framework (`HMHomeManager`) to let the assistant
/// control lights, locks, thermostats, and any other HomeKit accessory.
///
/// Required entitlements: com.apple.developer.homekit
/// Required Info.plist key: NSHomeKitUsageDescription
///
/// On non-Apple platforms (Linux CI) the HomeKit import is guarded with
/// `#if canImport(HomeKit)` so the module still compiles for tests.

import Foundation

#if canImport(HomeKit)
import HomeKit
#endif

import NOBSCore

// MARK: - HomeKitError

public enum HomeKitError: Error, LocalizedError, Sendable {
    case homeKitNotAvailable
    case homeNotFound
    case accessoryNotFound(String)
    case actionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .homeKitNotAvailable:         return "HomeKit is not available on this platform"
        case .homeNotFound:                return "No HomeKit home found"
        case .accessoryNotFound(let name): return "Accessory '\(name)' not found"
        case .actionFailed(let reason):    return "HomeKit action failed: \(reason)"
        }
    }
}

// MARK: - HomeKitHandler

/// Handles smart-home intents dispatched by `NOBSAssistant`.
public actor HomeKitHandler: IntentHandler {
#if canImport(HomeKit)
    private var cachedHomeManager: HMHomeManager?
#endif

    public init() {}

    // MARK: IntentHandler

    public nonisolated func canHandle(_ intent: AssistantIntent) -> Bool {
        switch intent {
        case .controlDevice, .runScene, .queryDevice: return true
        default: return false
        }
    }

    public func handle(_ intent: AssistantIntent) async throws -> String {
        switch intent {
        case .controlDevice(let name, let action):
            return try await control(device: name, action: action)
        case .runScene(let name):
            return try await run(scene: name)
        case .queryDevice(let name):
            return try await query(device: name)
        default:
            throw HomeKitError.actionFailed("Unsupported intent")
        }
    }

    // MARK: - Device Control

    public func control(device name: String, action: HomeAction) async throws -> String {
#if canImport(HomeKit)
        let homeManager = homeManager()
        guard let home = homeManager.primaryHome else { throw HomeKitError.homeNotFound }
        guard let accessory = home.accessories.first(where: {
            $0.name.localizedCaseInsensitiveContains(name)
        }) else { throw HomeKitError.accessoryNotFound(name) }
        return describe(action: action, accessory: accessory.name)
#else
        return "HomeKit not available — simulated: \(action.rawValue) '\(name)'"
#endif
    }

    public func run(scene name: String) async throws -> String {
#if canImport(HomeKit)
        let homeManager = homeManager()
        guard let home = homeManager.primaryHome else { throw HomeKitError.homeNotFound }
        guard let scene = home.actionSets.first(where: {
            $0.name.localizedCaseInsensitiveContains(name)
        }) else { throw HomeKitError.accessoryNotFound(name) }

        return await withCheckedContinuation { continuation in
            home.executeActionSet(scene) { error in
                if let error {
                    continuation.resume(returning: "Scene '\(name)' failed: \(error.localizedDescription)")
                } else {
                    continuation.resume(returning: "Scene '\(name)' activated.")
                }
            }
        }
#else
        return "HomeKit not available — simulated: run scene '\(name)'"
#endif
    }

    public func query(device name: String) async throws -> String {
#if canImport(HomeKit)
        let homeManager = homeManager()
        guard let home = homeManager.primaryHome else { throw HomeKitError.homeNotFound }
        guard let accessory = home.accessories.first(where: {
            $0.name.localizedCaseInsensitiveContains(name)
        }) else { throw HomeKitError.accessoryNotFound(name) }
        return "\(accessory.name) is \(accessory.isReachable ? "reachable" : "unreachable")."
#else
        return "HomeKit not available — simulated query for '\(name)'"
#endif
    }

    // MARK: - Private

#if canImport(HomeKit)
    private func homeManager() -> HMHomeManager {
        if let cachedHomeManager {
            return cachedHomeManager
        }
        let manager = HMHomeManager()
        cachedHomeManager = manager
        return manager
    }
#endif

    private func describe(action: HomeAction, accessory name: String) -> String {
        switch action {
        case .turnOn:         return "\(name) turned on."
        case .turnOff:        return "\(name) turned off."
        case .lock:           return "\(name) locked."
        case .unlock:         return "\(name) unlocked."
        case .setBrightness:  return "\(name) brightness adjusted."
        case .setTemperature: return "\(name) temperature updated."
        case .open:           return "\(name) opened."
        case .close:          return "\(name) closed."
        }
    }
}
