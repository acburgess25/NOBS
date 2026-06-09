import SwiftUI
import AppIntents
import TipKit
import NOBSCore
import NOBSAssistant
import NOBSSecurity
import NOBSDatabase
import NOBSReminders
import NOBSHomeKit
import NOBSCalendar
import NOBSCallKit
import NOBSiMessage
import NOBSIntents

@main
struct NOBSApp: App {
    @StateObject private var auth = APIClient()
    @State private var isUnlocked = true
    @State private var lockMessage: String?
    @State private var isBackgrounded = false
    @State private var showPaywall = false
    @AppStorage("onboarding_complete") private var onboardingComplete = false
    @AppStorage("biometric_lock_enabled") private var biometricLockEnabled = false
    @AppStorage("local_mode_enabled") private var localModeEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    private let capability = DeviceCapability.shared
    private let subscriptions = SubscriptionManager.shared

    let assistant: NOBSAssistant
    private let biometricGate = LocalAuthGate(
        reason: "Authenticate to unlock NOBS"
    )

    init() {
        // Seed shared App Group defaults so Siri / Widgets / Control intents work.
        if let shared = UserDefaults(suiteName: "group.com.nobsdash.nobs") {
            if shared.string(forKey: "tank_url") == nil {
                shared.set("https://nobsdash.com/ollama", forKey: "tank_url")
            }
            // Force the model on every cold start so existing installs upgrade in place.
            shared.set("qwen2.5-coder:14b", forKey: "tank_model")
            // F&F build: treat as subscribed and route to tank when AI is needed.
            shared.set(true, forKey: "nobs_subscribed")
            shared.set(true, forKey: "nobs_use_tank")
            if shared.string(forKey: "nobs_username") == nil {
                shared.set("there", forKey: "nobs_username")
            }
        }
        UserDefaults.standard.register(defaults: ["tank_beta_enabled": true])

        NOBSShortcutsProvider.updateAppShortcutParameters()

        // Background task handlers must be registered before the app finishes launching
        NOBSBackgroundTaskManager.shared.registerHandlers()

        // TipKit — configure once at app launch
        try? Tips.configure([
            .displayFrequency(.daily),
            .datastoreLocation(.applicationDefault)
        ])

        let icloudEnabled = UserDefaults.standard.bool(forKey: "icloud_sync_enabled")
        var storageMode: StorageMode = .localOnly
        if icloudEnabled {
            if FileManager.default.ubiquityIdentityToken != nil {
                storageMode = .iCloud(containerID: "iCloud.com.nobsdash.nobs")
            } else {
                UserDefaults.standard.set(false, forKey: "icloud_sync_enabled")
            }
        }
        do {
            try NOBSDatabase.shared.setup(storageMode: storageMode)
            print("✅ NOBSDatabase set up successfully with mode: \(storageMode.displayName)")
        } catch {
            print("❌ Failed to set up NOBSDatabase: \(error.localizedDescription)")
        }
        // Route AI to on-device (Apple Intelligence) or Tank based on device capability + subscription
        let aiBackend = DeviceCapability.shared.preferredBackend(
            subscribed: SubscriptionManager.shared.isSubscribed
        )
        let llmBackend: any LLMBackend
        switch aiBackend {
        case .onDevice:
            llmBackend = FoundationModelsClient()
        case .tank(let url, let model):
            llmBackend = ModelClient(config: ModelConfiguration(localEndpoint: url, modelName: model, timeoutSeconds: 90))
        }

        assistant = NOBSAssistant(
            backend: llmBackend,
            handlers: [
                MemoryIntentHandler(),
                RemindersHandler(isPersonalModeEnabled: { NOBSDatabase.shared.isPersonalModeEnabled }),
                HomeKitHandler(),
                CalendarHandler(),
                CallManager(),
                iMessageHandler(),
            ]
        )
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !onboardingComplete {
                    OnboardingView(isComplete: $onboardingComplete)
                        .transition(.opacity)
                } else if capability.requiresSubscriptionForAI && !subscriptions.isSubscribed {
                    // Device doesn't support Apple Intelligence — show paywall
                    PaywallView()
                        .transition(.opacity)
                } else if localModeEnabled {
                    ContentView(auth: auth, assistant: assistant)
                } else if auth.isAuthenticated {
                    if isUnlocked {
                        ContentView(auth: auth, assistant: assistant)
                    } else {
                        LockView(message: lockMessage) {
                            try await biometricGate.requireAuthentication()
                        } onSuccess: {
                            isUnlocked = true
                            lockMessage = nil
                        } onError: { error in
                            lockMessage = error.localizedDescription
                        }
                    }
                } else {
                    AuthView(auth: auth)
                }
            }
            .overlay {
                if isBackgrounded {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                isBackgrounded = false
                if biometricLockEnabled && !localModeEnabled && auth.isAuthenticated {
                    Task {
                        do {
                            try await biometricGate.requireAuthentication()
                            isUnlocked = true
                            lockMessage = nil
                        } catch {
                            isUnlocked = false
                            lockMessage = error.localizedDescription
                        }
                    }
                }
            case .background, .inactive:
                if biometricLockEnabled { isUnlocked = false }
                isBackgrounded = true
                Task { await biometricGate.invalidate() }
                NOBSBackgroundTaskManager.shared.scheduleAppRefresh()
            @unknown default: break
            }
        }
        .onChange(of: auth.username) { _, name in
            guard !name.isEmpty else { return }
            Task { await assistant.setUserName(name) }
        }
    }
}

struct LockView: View {
    let message: String?
    let authenticate: () async throws -> Void
    let onSuccess: () -> Void
    let onError: (Error) -> Void
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.nobsBg.ignoresSafeArea()
            VStack(spacing: Spacing.xl) {
                Spacer()
                NobsLogo(size: 80)
                    .nobsShadow(strong: true)
                VStack(spacing: Spacing.sm) {
                    Text("NOBS Locked")
                        .font(NOBSFont.title2())
                        .foregroundStyle(Color.nobsPrimary)
                    if let msg = message {
                        Text(msg)
                            .font(NOBSFont.footnote())
                            .foregroundStyle(Color.nobsRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }
                }
                NOBSButton(
                    label: "Unlock",
                    icon: "faceid",
                    style: .primary,
                    size: .large,
                    fullWidth: true,
                    isLoading: isLoading,
                    disabled: isLoading,
                    action: {
                        isLoading = true
                        Task {
                            do {
                                try await authenticate()
                                onSuccess()
                            } catch {
                                onError(error)
                            }
                            isLoading = false
                        }
                    }
                )
                .padding(.horizontal, Spacing.md)
                Spacer()
            }
        }
        .task {
            do {
                try await authenticate()
                onSuccess()
            } catch {
                onError(error)
            }
            isLoading = false
        }
    }
}
