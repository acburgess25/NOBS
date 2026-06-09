/// DeviceCapability — Device & AI routing intelligence
///
/// Determines whether the current device can run Apple Intelligence
/// (FoundationModels) on-device, or needs to fall back to Tank server.
/// Also monitors battery and thermal state for adaptive routing.

import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - AI Backend

public enum AIBackend: Equatable {
    /// Apple's on-device LLM via FoundationModels framework (free, private)
    case onDevice
    /// Tank server via Ollama/ai-proxy (requires NOBS Server subscription)
    case tank(url: URL, model: String)
}

// MARK: - Device Capability

@MainActor
public final class DeviceCapability: ObservableObject {

    public static let shared = DeviceCapability()

    // MARK: - Published state

    /// Whether this device hardware supports Apple Intelligence
    @Published public private(set) var supportsAppleIntelligence: Bool = false

    /// Whether Apple Intelligence is actually available right now
    /// (enabled in Settings, correct region, model downloaded)
    @Published public private(set) var appleIntelligenceReady: Bool = false

    /// Current battery level 0.0–1.0, or -1 if unknown
    @Published public private(set) var batteryLevel: Float = 1.0

    /// Whether battery is low (< 20%)
    @Published public private(set) var isBatteryLow: Bool = false

    /// Whether device is running hot
    @Published public private(set) var isThermallyThrottled: Bool = false

    // MARK: - Tank config
    public var tankURL   = URL(string: "https://nobsdash.com/ollama")!
    public var tankModel = "qwen2.5-coder:14b"

    // MARK: - Init

    private init() {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
        refresh()
        startMonitoring()
    }

    // MARK: - Backend routing

    /// The backend that should be used right now.
    /// Takes into account device capability, subscription, battery, and thermal state.
    public func preferredBackend(subscribed: Bool) -> AIBackend {
        let tankBetaEnabled = UserDefaults.standard.bool(forKey: "tank_beta_enabled")
        let wantsTank = subscribed || tankBetaEnabled

        // Force Tank if device doesn't support Apple Intelligence
        guard supportsAppleIntelligence && appleIntelligenceReady else {
            return wantsTank ? .tank(url: tankURL, model: tankModel) : .onDevice // caller handles no-subscription
        }

        // Fall back to Tank when battery is critically low or device is throttling
        if (isBatteryLow || isThermallyThrottled) && wantsTank {
            return .tank(url: tankURL, model: tankModel)
        }

        // Honour explicit beta opt-in even on capable devices
        if tankBetaEnabled {
            return .tank(url: tankURL, model: tankModel)
        }

        return .onDevice
    }

    /// Whether the user needs a subscription to use AI at all
    public var requiresSubscriptionForAI: Bool {
        let tankBetaEnabled = UserDefaults.standard.bool(forKey: "tank_beta_enabled")
        return !(appleIntelligenceReady || tankBetaEnabled)
    }

    // MARK: - Refresh

    public func refresh() {
        supportsAppleIntelligence = Self.checkHardwareSupport()
        appleIntelligenceReady    = Self.checkAppleIntelligenceReady()
        updateBatteryState()
        updateThermalState()
    }

    // MARK: - Hardware check

    /// iPhone 15 Pro / Pro Max and iPhone 16+ support Apple Intelligence.
    private static func checkHardwareSupport() -> Bool {
        #if targetEnvironment(simulator)
        return true // always allow in simulator for dev
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingUTF8: $0) ?? "" }
        }
        // A17 Pro (iPhone 15 Pro) and A18/A18 Pro (iPhone 16 family)
        // Maps to: iPhone16,1 iPhone16,2 (15 Pro), iPhone17,x (16 family)
        let supported = ["iPhone16,1", "iPhone16,2",       // 15 Pro, 15 Pro Max
                         "iPhone17,1", "iPhone17,2",       // 16, 16 Plus
                         "iPhone17,3", "iPhone17,4",       // 16 Pro, 16 Pro Max
                         "iPhone18,1", "iPhone18,2",       // 17, 17 Air (future)
                         "iPhone18,3", "iPhone18,4"]       // 17 Pro, 17 Pro Max
        return supported.contains(machine)
        #endif
    }

    /// Check if Apple Intelligence is enabled and the model is available.
    private static func checkAppleIntelligenceReady() -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        // FoundationModels requires iOS 26+, supported hardware, Apple Intelligence
        // enabled in Settings, and a downloaded local model.
        return checkHardwareSupport() && FoundationModelsClient.isAvailable
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.updateBatteryState() }

        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.updateBatteryState() }
        #endif

        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.updateThermalState() }
    }

    private func updateBatteryState() {
        #if canImport(UIKit)
        let level = UIDevice.current.batteryLevel
        batteryLevel = level
        isBatteryLow = level >= 0 && level < 0.20
        #endif
        // On macOS, UIDevice is unavailable; batteryLevel stays at its default (1.0)
    }

    private func updateThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        isThermallyThrottled = state == .serious || state == .critical
    }
}

// MARK: - Capability Description (for UI)

public extension DeviceCapability {

    var statusTitle: String {
        if supportsAppleIntelligence && appleIntelligenceReady {
            return "Running on Apple Intelligence"
        } else if supportsAppleIntelligence {
            return "Apple Intelligence Not Enabled"
        } else {
            return "Apple Intelligence Not Supported"
        }
    }

    var statusSubtitle: String {
        if supportsAppleIntelligence && appleIntelligenceReady {
            return "All AI runs privately on your device. No data leaves your iPhone."
        } else if supportsAppleIntelligence {
            return "Enable Apple Intelligence in Settings → Apple Intelligence & Siri AI."
        } else {
            return "Requires iPhone 15 Pro, iPhone 15 Pro Max, or iPhone 16 and later."
        }
    }

    var statusIcon: String {
        if supportsAppleIntelligence && appleIntelligenceReady { return "cpu.fill" }
        if supportsAppleIntelligence { return "exclamationmark.circle.fill" }
        return "iphone.slash"
    }
}
