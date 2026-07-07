import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isScanningQR = false
    private let accent = Color.nobsAccent

    var body: some View {
        List {
            Section("Processing now") {
                LabeledContent("Chat", value: model.tankAvailable ? "Tank available" : "Local fallback")
                LabeledContent("Calendar", value: "On this iPhone")
                if TankConfiguration.hasSavedConnection, !model.tankAvailable {
                    Button {
                        Task { await model.refreshTankStatus() }
                    } label: {
                        Label("Try reconnecting to Tank", systemImage: "arrow.clockwise")
                    }
                    .accessibilityHint("Checks whether your saved Tank is reachable on the network")
                }
            }

            Section {
                SignInView(mode: .settings) {}
            } header: {
                Text("Quick Connect")
            } footer: {
                Text("Sign in once and NOBS automatically reconnects to Tank whenever you're home.")
            }

            Section("Manual Tank Setup") {
                TextField("Tank address", text: $model.tankAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("Device token", text: $model.tankToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Button(model.tankAvailable ? "Save and check again" : "Save and check connection") {
                        Task { await model.saveTankConnection() }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: openScanner) {
                        Label("Scan QR", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                }
                Label(
                    model.tankAvailable ? "Connected on your private network" : "Not connected; local fallback is active",
                    systemImage: model.tankAvailable ? "checkmark.circle.fill" : "iphone"
                )
                .foregroundStyle(model.tankAvailable ? accent : .secondary)
            }
            SupportView()

            Section("Boundaries") {
                Label("Passwords are off-limits", systemImage: "key.slash")
                Label("Financial accounts are off-limits", systemImage: "creditcard.trianglebadge.exclamationmark")
                Label("No data is sold or used for advertising", systemImage: "eye.slash")
            }
        }
        .nobsListScreen()
        .sheet(isPresented: $isScanningQR) {
            NavigationStack {
                ScannerView(
                    onScan: handleScan,
                    onCancel: { isScanningQR = false }
                )
                .ignoresSafeArea()
                .navigationTitle("Scan Tank QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isScanningQR = false }
                    }
                }
            }
        }
    }

    private func openScanner() {
        guard ScannerView.isAvailable else {
            model.lastError = "QR scanning is not available on this device."
            return
        }
        isScanningQR = true
    }

    private func handleScan(payload: String) {
        guard let url = URL(string: payload) else { return }
        model.applyTankPayload(from: url)
        isScanningQR = false
        Task { await model.saveTankConnection() }
    }
}
