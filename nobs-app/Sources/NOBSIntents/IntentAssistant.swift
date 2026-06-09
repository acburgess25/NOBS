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
        let isPersonal = !defaults.bool(forKey: "work_mode_active")
        let isSubscribed = defaults.bool(forKey: "nobs_subscribed")
        let context: DataContext = isPersonal ? .personal : .work
        let userName = defaults.string(forKey: "nobs_username") ?? "there"

        let backend = resolveBackend(from: defaults, isSubscribed: isSubscribed)

        return NOBSAssistant(
            backend: backend,
            handlers: [
                MemoryIntentHandler(),
                RemindersHandler(isPersonalModeEnabled: { isPersonal }),
                HomeKitHandler(),
            ],
            userName: userName,
            dataContext: context
        )
    }

    private static func resolveBackend(from defaults: UserDefaults, isSubscribed: Bool) -> any LLMBackend {
        // Prefer on-device Apple Intelligence when available
        if FoundationModelsClient.isAvailable {
            return FoundationModelsClient()
        }
        // Fall back to Tank if the user has a subscription and a URL configured
        if isSubscribed,
           let tankURL = defaults.string(forKey: "tank_url"),
           let url = URL(string: tankURL) {
            let model = defaults.string(forKey: "tank_model") ?? "llama3.1:8b"
            return ModelClient(config: ModelConfiguration(localEndpoint: url, modelName: model))
        }
        // Final fallback: localhost Ollama (developer/testing scenario)
        return ModelClient(config: .localhost)
    }

    /// Scans the Tank server. NOTE: stubbed in the NOBSIntents target since
    /// APIClient lives in the app target. The NOBSApp wraps this with the real
    /// network call. We'll move APIClient to NOBSCore in a follow-up.
    public static func scanServer() async throws -> String {
        throw NSError(domain: "NOBSIntents", code: -10, userInfo: [
            NSLocalizedDescriptionKey: "scanServer is not yet available in App Intents context"
        ])
    }

}
