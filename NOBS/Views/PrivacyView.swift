import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isScanningQR = false
    @State private var isPickingConfigFolder = false
    private let accent = Color.nobsAccent

    var body: some View {
        List {
            Section("Processing now") {
                LabeledContent("Chat", value: chatProcessingSummary)
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

            Section("Apple private cloud") {
                if model.showPCCBadge {
                    LabeledContent("Status", value: AppleModelProvider.availabilityDescription)
                    PCCQuotaStatusView(quota: model.pccQuotaStatus) {
                        model.showPCCQuotaUpgradeOptions()
                    }
                } else {
                    Label("Apple private cloud — coming soon", systemImage: "lock.icloud")
                        .foregroundStyle(.secondary)
                    Text("Private Cloud Compute routing ships in v1.1 after entitlement approval and device testing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("When Tank is away") {
                    Text(model.routingPreferences.tankOfflineBehavior.title)
                }
                Button("Reset routing preferences") {
                    model.routingPreferences = .default
                    model.persistRoutingPreferences()
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
                if let name = model.externalConfigFolderName {
                    LabeledContent("Folder", value: name)
                } else {
                    Text("No folder linked")
                        .foregroundStyle(.secondary)
                }
                if let synced = model.externalConfigLastSyncAt {
                    LabeledContent("Last sync") {
                        Text(synced, style: .relative)
                    }
                }
                if let status = model.externalConfigStatus, !status.isEmpty {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    isPickingConfigFolder = true
                } label: {
                    Label(
                        model.externalConfigFolderName == nil ? "Choose iCloud folder" : "Change folder",
                        systemImage: "folder.badge.gearshape"
                    )
                }
                if model.externalConfigFolderName != nil {
                    Button {
                        Task { await model.syncExternalConfigFromFolder() }
                    } label: {
                        Label("Sync now", systemImage: "arrow.clockwise")
                    }
                    Button("Unlink folder", role: .destructive) {
                        model.unlinkExternalConfigFolder()
                    }
                }
            } header: {
                Text("iCloud config folder")
            } footer: {
                Text("Place profile.json and tank.json in an iCloud Drive folder. NOBS re-reads them when you open the app. Never put device tokens in these files.")
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
        .sheet(isPresented: $isPickingConfigFolder) {
            ConfigFolderPicker(
                onPick: { url in
                    isPickingConfigFolder = false
                    Task { await model.linkExternalConfigFolder(url) }
                },
                onCancel: { isPickingConfigFolder = false }
            )
            .ignoresSafeArea()
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

    private var chatProcessingSummary: String {
        if model.tankAvailable { return "Tank available" }
        switch model.routingPreferences.tankOfflineBehavior {
        case .useAppleCloud: return "Apple Cloud when available"
        case .useNOBScloud: return "NOBScloud when subscribed"
        case .queueForTank: return "Local until Tank returns"
        case .localOnly: return "Local only"
        case .askEachTime: return "Local fallback (asks when needed)"
        }
    }
}
