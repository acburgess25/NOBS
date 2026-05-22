import SwiftUI
import NOBSDatabase

struct SettingsView: View {
    @ObservedObject var auth: APIClient
    @AppStorage("icloud_sync_enabled") private var icloudSync = false
    @AppStorage("onboarding_complete") private var onboardingComplete = false
    @State private var showDisclosure = false
    @State private var pendingToggle = false
    @State private var showOnboardingAlert = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                preferencesSection
                storageSection
                if NOBSDatabase.shared.isPersonalModeEnabled {
                    kitchenSection
                }
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("Share Your Pantry?", isPresented: $showDisclosure) {
                Button("Keep Local", role: .cancel) {
                    pendingToggle = false
                }
                Button("Enable Shared Pantry") {
                    icloudSync = true
                    pendingToggle = false
                }
            } message: {
                Text("This shares your encrypted pantry with iCloud. Your data stays encrypted — Apple can't read it. Restart the app after enabling.")
            }
            .alert("Replay the Tour?", isPresented: $showOnboardingAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Show Tour") {
                    onboardingComplete = false
                }
            } message: {
                Text("The welcome tour will show on next launch so you can set your preferences fresh.")
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            HStack {
                Label("Username", systemImage: "person.circle")
                Spacer()
                Text(auth.username)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            .accessibilityLabel("Logged in as \(auth.username)")

            Button("Sign Out", role: .destructive) {
                auth.logout()
            }
            .accessibilityHint("Logs out and clears local data")
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
                ? "Your pantry is shared with iCloud. Data stays encrypted end-to-end."
                : "All data stays on-device. No cloud storage."
            )
        }
    }

    private var kitchenSection: some View {
        Section {
            HStack {
                Label("Server", systemImage: "server.rack")
                Spacer()
                Text("192.168.0.77")
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            HStack {
                Label("Model", systemImage: "cpu")
                Spacer()
                Text("qwen2:1.5b")
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
            HStack {
                Label("API", systemImage: "antenna.radiowaves.left.and.right")
                Spacer()
                Text("nobsdash.com")
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }
        } header: {
            Label("Your Kitchen (Local AI)", systemImage: "house")
        } footer: {
            Text("Your requests go to a dedicated local AI server on your home network. No data leaves your control.")
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
                .foregroundStyle(.blue)
        }
    }
}
