import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isScanningQR = false
    private let accent = Color.nobsAccent

    var body: some View {
        List {
            Section("Tank sync") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: model.tankSyncStatus.symbol)
                        .foregroundStyle(model.tankAvailable ? accent : .secondary)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.tankSyncStatus.label)
                            .font(.subheadline.weight(.semibold))
                        if let detail = model.tankLastConnectionError, !model.tankAvailable {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if model.pendingOfflineMessageCount > 0 {
                            Text("\(model.pendingOfflineMessageCount) chat message\(model.pendingOfflineMessageCount == 1 ? "" : "s") will send when Tank reconnects.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                LabeledContent("Chat route", value: model.tankAvailable ? "Tank" : model.foundationModelsAvailable ? "On-device AI" : "Local rules")
                LabeledContent("On-device AI", value: model.foundationModelsStatus)
                LabeledContent("Calendar", value: "On this iPhone")

                if !model.tankAvailable {
                    Button {
                        Task { await model.reconnectToTank() }
                    } label: {
                        Label(
                            model.isReconnecting ? "Reconnecting…" : "Reconnect to Tank",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(model.isReconnecting)
                }
            }

            Section {
                SignInView(mode: .settings) {}
            } header: {
                Text("Quick Connect")
            } footer: {
                Text("Sign in once and NOBS automatically reconnects to Tank whenever you're home.")
            }

            Section {
                if !model.discoveredTanks.isEmpty {
                    ForEach(model.discoveredTanks) { tank in
                        Button {
                            model.tankAddress = tank.url.absoluteString
                            Task { await model.saveTankConnection() }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tank.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(tank.url.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

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
            } header: {
                Text("Manual Tank Setup")
            } footer: {
                Text("NOBS browses for _nobs._tcp on your LAN. If discovery fails, enter your Tank IP (for example http://192.168.1.100:8000).")
            }
            SupportView()

            Section("Boundaries") {
                Label("Passwords are off-limits", systemImage: "key.slash")
                Label("Financial accounts are off-limits", systemImage: "creditcard.trianglebadge.exclamationmark")
                Label("No data is sold or used for advertising", systemImage: "eye.slash")
            }
        }
        .scrollContentBackground(.hidden)
        .task {
            if !model.tankAvailable {
                await model.browseForTanks()
            }
        }
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
