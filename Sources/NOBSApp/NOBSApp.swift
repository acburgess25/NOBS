import SwiftUI
import NOBSCore
import NOBSAssistant
import NOBSSecurity
import NOBSDatabase
import NOBSReminders
import NOBSHomeKit
import NOBSCallKit
import NOBSiMessage

@main
struct NOBSApp: App {
    @StateObject private var auth = APIClient()
    @State private var isUnlocked = false
    @State private var lockMessage: String?
    @State private var isBackgrounded = false
    @State private var showPaywall = false
    @AppStorage("onboarding_complete") private var onboardingComplete = false
    @Environment(\.scenePhase) private var scenePhase

    private let capability = DeviceCapability.shared
    private let subscriptions = SubscriptionManager.shared

    let assistant: NOBSAssistant
    private let biometricGate = LocalAuthGate(
        reason: "Authenticate to unlock NOBS"
    )

    init() {
        let icloudEnabled = UserDefaults.standard.bool(forKey: "icloud_sync_enabled")
        var storageMode: StorageMode = .localOnly
        if icloudEnabled {
            if FileManager.default.ubiquityIdentityToken != nil {
                storageMode = .iCloud(containerID: "iCloud.com.nobs.app")
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
        // Route AI to on-device or Tank based on device capability + subscription
        let backend = DeviceCapability.shared.preferredBackend(
            subscribed: SubscriptionManager.shared.isSubscribed
        )
        let modelConfig: ModelConfiguration
        switch backend {
        case .onDevice:
            // FoundationModels is invoked directly in NOBSAssistant; config is unused
            modelConfig = .localhost
        case .tank(let url, let model):
            modelConfig = ModelConfiguration(localEndpoint: url, modelName: model)
        }

        assistant = NOBSAssistant(
            config: modelConfig,
            handlers: [
                MemoryIntentHandler(),
                RemindersHandler(isPersonalModeEnabled: { NOBSDatabase.shared.isPersonalModeEnabled }),
                HomeKitHandler(),
                CallManager(),
                iMessageHandler(),
            ],
            userName: "Alex"
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
                if auth.isAuthenticated {
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
                isUnlocked = false
                isBackgrounded = true
                Task { await biometricGate.invalidate() }
            @unknown default: break
            }
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
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("NOBS Locked")
                .font(.title2.bold())
            if let msg = message {
                Text(msg)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            Button {
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
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Try Again")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            Spacer()
        }
        .padding()
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
