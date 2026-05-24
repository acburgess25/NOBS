/// IntentAssistant — Lightweight assistant factory for App Intents
///
/// Each intent invocation may run in a fresh background process.
/// This builds a ready-to-use NOBSAssistant from shared UserDefaults config.

import Foundation
import NOBSCore
import NOBSAssistant
import NOBSDatabase
import NOBSHomeKit
import NOBSReminders

public enum IntentAssistant {

    private static let groupID = "group.com.nobsdash.nobs"

    /// Returns a configured NOBSAssistant using the stored Tank/on-device settings.
    public static func make() -> NOBSAssistant {
        let defaults = UserDefaults(suiteName: groupID) ?? .standard
        let tankURL   = defaults.string(forKey: "tank_url")   ?? "http://100.96.97.50:11434"
        let tankModel = defaults.string(forKey: "tank_model") ?? "llama3.1:8b"
        let isPersonal = !defaults.bool(forKey: "work_mode_active")
        let isSubscribed = defaults.bool(forKey: "nobs_subscribed")

        // Read stored backend preference rather than calling @MainActor DeviceCapability
        let useTank = isSubscribed && defaults.bool(forKey: "nobs_use_tank")
        let config: ModelConfiguration
        if useTank {
            config = ModelConfiguration(
                localEndpoint: URL(string: tankURL)!,
                modelName: tankModel
            )
        } else {
            config = .localhost
        }

        let context: DataContext = isPersonal ? .personal : .work

        return NOBSAssistant(
            config: config,
            handlers: [
                MemoryIntentHandler(),
                RemindersHandler(isPersonalModeEnabled: { isPersonal }),
                HomeKitHandler(),
            ],
            userName: defaults.string(forKey: "nobs_username") ?? "there",
            dataContext: context
        )
    }

    /// Scans the Tank server and returns the result.
    public static func scanServer() async throws -> String {
        let apiClient = APIClient()
        return try await apiClient.scanTank()
    }
}
