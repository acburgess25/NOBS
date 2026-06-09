import SwiftUI
import NOBSDatabase

struct SettingsView: View {
    @ObservedObject var auth: APIClient
    @AppStorage("icloud_sync_enabled") private var icloudSync = false
    @AppStorage("onboarding_complete") private var onboardingComplete = false
    @AppStorage("local_mode_enabled") private var localModeEnabled = true
    @AppStorage("tank_beta_enabled") private var tankBetaEnabled = false
    @State private var showDisclosure = false
    @State private var pendingToggle = false
    @State private var showOnboardingAlert = false
    @State private var showAgencyPaywall = false
    @State private var notificationStatus = "Not enabled"
    @State private var manager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                preferencesSection
                agencySection
                storageSection
                notificationsSection
                if NOBSDatabase.shared.isPersonalModeEnabled {
                    serverSection
                }
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("Enable iCloud Sync?", isPresented: $showDisclosure) {
                Button("Keep Local", role: .cancel) {
                    pendingToggle = false
                }
                Button("Enable iCloud Sync") {
                    icloudSync = true
                    pendingToggle = false
                }
            } message: {
                Text("This syncs your encrypted data with iCloud. Your data stays encrypted — Apple can't read it. Restart the app after enabling.")
            }
            .alert("Replay the Tour?", isPresented: $showOnboardingAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Show Tour") {
                    onboardingComplete = false
                }
            } message: {
                Text("The welcome tour will show on next launch so you can set your preferences fresh.")
            }
            .task {
                notificationStatus = await NOBSNotificationManager.shared.authorizationStatusText()
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            HStack {
                Label(localModeEnabled ? "Mode" : "Username", systemImage: "person.circle")
                Spacer()
                Text(localModeEnabled ? "Local" : auth.username)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            .accessibilityLabel(localModeEnabled ? "Using local mode" : "Logged in as \(auth.username)")

            Toggle(isOn: $localModeEnabled) {
                Label("Use without account", systemImage: "iphone")
            }

            if !localModeEnabled {
                Button("Sign Out", role: .destructive) {
                    auth.logout()
                }
                .accessibilityHint("Logs out and clears local data")
            }
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            NavigationLink {
                ProfileView()
            } label: {
                Label("Edit Profile", systemImage: "person.text.rectangle")
            }

            Button {
                showOnboardingAlert = true
            } label: {
                Label("Show Welcome Tour", systemImage: "arrow.triangle.capsulepath")
            }
        }
    }

    private var agencySection: some View {
        Section {
            Button {
                showAgencyPaywall = true
            } label: {
                HStack {
                    Label("NOBS Agency", systemImage: "building.2.fill")
                    Spacer()
                    if let tier = manager.agencyTier {
                        Text(tier.displayName)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        Text("Not subscribed")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
            }
        } footer: {
            Text(manager.hasAgencyAccess
                ? "AI social media agency running on your Tank server."
                : "Subscribe to unlock AI-powered social media management on Tank.")
        }
        .sheet(isPresented: $showAgencyPaywall) {
            AgencyPaywallView(auth: auth)
                .presentationDetents([.large])
        }
    }

    private var storageSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { icloudSync },
                set: { newValue in
                    if newValue {
                        showDisclosure = true
                        pendingToggle = true
                    } else {
                        icloudSync = false
                    }
                }
            )) {
                Label("iCloud Sync", systemImage: "icloud")
            }
            .accessibilityHint("Syncs encrypted data to iCloud")
        } footer: {
            Text(icloudSync
                ? "Your data is synced with iCloud. Data stays encrypted end-to-end."
                : "All data stays on-device. No cloud storage."
            )
        }
    }

    private var notificationsSection: some View {
        Section {
            HStack {
                Label("Notifications", systemImage: "bell.badge")
                Spacer()
                Text(notificationStatus)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    let granted = await NOBSNotificationManager.shared.requestPermission()
                    notificationStatus = granted ? "Enabled" : await NOBSNotificationManager.shared.authorizationStatusText()
                }
            } label: {
                Label("Enable Notifications", systemImage: "bell.fill")
            }
        } footer: {
            Text("NOBS asks only when you choose. Reminders and proposed plans can still stay local until you enable alerts.")
        }
    }

    private var serverSection: some View {
        Section {
            HStack {
                Label("Backend", systemImage: "cpu")
                Spacer()
                Text(tankBetaEnabled ? "Tank fallback" : "Local first")
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            Toggle(isOn: $tankBetaEnabled) {
                Label("Use Tank fallback", systemImage: "server.rack")
            }
            HStack {
                Label("API", systemImage: "antenna.radiowaves.left.and.right")
                Spacer()
                Text("nobsdash.com")
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
        } header: {
            Label("AI Backend", systemImage: "cpu")
        } footer: {
            Text("NOBS uses Apple Intelligence on-device when available, with Tank as a fallback. No data leaves your control.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("2.0.0")
                    .foregroundStyle(.secondary)
            }
            Link(destination: URL(string: "https://nobsdash.com")!) {
                Label("Website", systemImage: "safari")
            }
            Label("Built with ❤️ for WWDC 26", systemImage: "sparkles")
                .foregroundStyle(Color.nobsAccent)
        }
    }
}
