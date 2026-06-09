import SwiftUI

struct SettingsView: View {
    @Environment(CommandCenterStore.self) private var store
    @State private var launchAtLogin = false
    @State private var adaptiveMemory = true
    @State private var askBeforeCloud = true

    var body: some View {
        Form {
            Section("Runtime") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                Toggle("Adaptive memory distillation", isOn: $adaptiveMemory)
                Toggle("Ask before using external server compute", isOn: $askBeforeCloud)
            }

            Section("Folders") {
                Button("Open AI Root") {
                    store.openAIRoot()
                }
                Button("Open NOBS App") {
                    store.openNOBSApp()
                }
                Button("Open Vault") {
                    store.openVault()
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(minWidth: 520, minHeight: 420)
    }
}
