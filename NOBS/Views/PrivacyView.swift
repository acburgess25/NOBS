import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var model: AppModel
    @State private var settingsDraft = ""
    @State private var isScanningQR = false
    @State private var isPickingConfigFolder = false
    @State private var isShowingTankSetup = false
    @State private var isShowingConnections = false
    @State private var isShowingSupport = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introduction
                conversationalControl
                Divider()
                currentSetup
                secondaryLinks
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .nobsReadableWidth(640)
        }
        .nobsScreenBackground()
        .sheet(isPresented: $isShowingTankSetup) { tankSetupSheet }
        .sheet(isPresented: $isShowingConnections) { connectionsSheet }
        .sheet(isPresented: $isShowingSupport) { supportSheet }
        .sheet(isPresented: $isScanningQR) { scannerSheet }
        .sheet(isPresented: $isPickingConfigFolder) { configFolderSheet }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sun.max.fill")
                    .font(.title3)
                    .foregroundStyle(Color.nobsForest)
                    .frame(width: 44, height: 44)
                    .background(Color.nobsSagePale, in: Circle())
                    .accessibilityHidden(true)

                Text("You’re set to **\(model.profile.proactivityLevel.title.lowercased())**, **\(model.profile.privacyComfort.title.lowercased())** support. What would you like to change?")
                    .font(.system(.title3, design: .serif, weight: .medium))
                    .foregroundStyle(Color.nobsInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var conversationalControl: some View {
        HStack(spacing: 10) {
            TextField("Make mornings quieter…", text: $settingsDraft, axis: .vertical)
                .lineLimit(1...3)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .onSubmit(openSettingsConversation)

            Button(action: openSettingsConversation) {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.nobsForest, in: Circle())
            }
            .disabled(trimmedSettingsDraft.isEmpty)
            .opacity(trimmedSettingsDraft.isEmpty ? 0.45 : 1)
            .accessibilityLabel("Ask NOBS to change this setting")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        .background(Color.nobsCanvas)
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.nobsGreen.opacity(0.58), lineWidth: 1.5)
        }
    }

    private var currentSetup: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your current setup")
                .nobsEyebrow()
                .padding(.bottom, 8)

            Menu {
                ForEach(PrivacyComfort.allCases, id: \.self) { comfort in
                    Button(comfort.title) {
                        model.updateProfile { $0.privacyComfort = comfort }
                    }
                }
            } label: {
                SettingsSummaryRow(
                    symbol: "lock",
                    title: "Privacy",
                    detail: privacyDetail,
                    value: model.profile.privacyComfort.title
                )
            }

            Divider().padding(.leading, 56)

            Menu {
                ForEach(ProactivityLevel.allCases, id: \.self) { level in
                    Button(level.title) {
                        model.updateProfile { $0.proactivityLevel = level }
                    }
                }
            } label: {
                SettingsSummaryRow(
                    symbol: "sun.max",
                    title: "Daily rhythm",
                    detail: "Morning briefing and timely check-ins.",
                    value: model.profile.proactivityLevel.title
                )
            }

            Divider().padding(.leading, 56)

            Menu {
                ForEach(TonePreference.allCases, id: \.self) { tone in
                    Button(tone.title) {
                        model.updateProfile { $0.preferredTone = tone }
                    }
                }
            } label: {
                SettingsSummaryRow(
                    symbol: "message",
                    title: "Communication",
                    detail: communicationDetail,
                    value: model.profile.preferredTone.title
                )
            }

            Divider().padding(.leading, 56)

            Button {
                model.section = .approvals
            } label: {
                SettingsSummaryRow(
                    symbol: "hand.raised",
                    title: "Actions",
                    detail: "NOBS asks before making changes.",
                    value: model.pendingDecisionCount == 0 ? "Always ask first" : "\(model.pendingDecisionCount) waiting"
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var secondaryLinks: some View {
        VStack(spacing: 0) {
            SettingsLinkRow(symbol: "person.2", title: "Connections & permissions", detail: connectionDetail) {
                isShowingConnections = true
            }
            Divider().padding(.leading, 56)
            SettingsLinkRow(symbol: "accessibility", title: "Accessibility", detail: accessibilityDetail) {
                openSettingsPrompt("Help me adjust text, voice, and interaction preferences.")
            }
            Divider().padding(.leading, 56)
            SettingsLinkRow(symbol: "questionmark.circle", title: "Account & support", detail: "Sign in, purchases, help, and feedback.") {
                isShowingSupport = true
            }
        }
    }

    private var connectionsSheet: some View {
        NavigationStack {
            List {
                Section("Processing now") {
                    LabeledContent("Chat", value: chatProcessingSummary)
                    LabeledContent("Calendar", value: "On this iPhone")
                    if TankConfiguration.hasSavedConnection, !model.tankAvailable {
                        Button("Try reconnecting to Tank", systemImage: "arrow.clockwise") {
                            Task { await model.refreshTankStatus() }
                        }
                    }
                }

                Section("Connections") {
                    SignInView(mode: .settings) {}
                    Button("Tank setup", systemImage: "server.rack") {
                        isShowingConnections = false
                        isShowingTankSetup = true
                    }
                    Button("Choose iCloud config folder", systemImage: "folder.badge.gearshape") {
                        isShowingConnections = false
                        isPickingConfigFolder = true
                    }
                }

                Section("Boundaries") {
                    Label("Passwords are off-limits", systemImage: "key.slash")
                    Label("Financial accounts are off-limits", systemImage: "creditcard.trianglebadge.exclamationmark")
                    Label("No data is sold or used for advertising", systemImage: "eye.slash")
                }
            }
            .nobsListScreen()
            .navigationTitle("Connections & permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { isShowingConnections = false } }
        }
        .presentationBackground(Color.nobsCanvas)
    }

    private var tankSetupSheet: some View {
        NavigationStack {
            Form {
                Section("Connect to your Tank") {
                    Text("NOBS finds your Tank automatically. Sign in with Apple to connect — no address, QR code, or device token needed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    SignInView(mode: .settings) {}
                }

                Section("Advanced setup") {
                    TextField("Tank address", text: $model.tankAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Device token", text: $model.tankToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(model.tankAvailable ? "Save and check again" : "Use this connection") {
                        Task { await model.saveTankConnection() }
                    }
                    Button("Scan pairing QR", systemImage: "qrcode.viewfinder", action: openScanner)
                    Label(
                        model.tankAvailable ? "Connected on your private network" : "Local fallback is active",
                        systemImage: model.tankAvailable ? "checkmark.circle.fill" : "iphone"
                    )
                    .foregroundStyle(model.tankAvailable ? Color.nobsAccent : .secondary)
                }

                Section("When Tank is away") {
                    Picker("Fallback", selection: $model.routingPreferences.tankOfflineBehavior) {
                        ForEach(TankOfflineBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    }
                    .onChange(of: model.routingPreferences.tankOfflineBehavior) {
                        model.persistRoutingPreferences()
                    }
                    Button("Reset routing preferences") {
                        model.routingPreferences = .default
                        model.persistRoutingPreferences()
                    }
                }
            }
            .nobsListScreen()
            .navigationTitle("Tank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { isShowingTankSetup = false } }
        }
        .presentationBackground(Color.nobsCanvas)
    }

    private var supportSheet: some View {
        NavigationStack {
            List { SupportView() }
                .nobsListScreen()
                .navigationTitle("Account & support")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { isShowingSupport = false } }
        }
        .presentationBackground(Color.nobsCanvas)
    }

    private var scannerSheet: some View {
        NavigationStack {
            ScannerView(onScan: handleScan, onCancel: { isScanningQR = false })
                .ignoresSafeArea()
                .navigationTitle("Scan Tank QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Cancel") { isScanningQR = false } }
        }
    }

    private var configFolderSheet: some View {
        ConfigFolderPicker(
            onPick: { url in
                isPickingConfigFolder = false
                Task { await model.linkExternalConfigFolder(url) }
            },
            onCancel: { isPickingConfigFolder = false }
        )
        .ignoresSafeArea()
    }

    private func openSettingsConversation() {
        guard !trimmedSettingsDraft.isEmpty else { return }
        openSettingsPrompt(trimmedSettingsDraft)
        settingsDraft = ""
    }

    private func openSettingsPrompt(_ prompt: String) {
        model.handleDeepLink(chatPrompt: prompt)
    }

    private func openScanner() {
        guard ScannerView.isAvailable else {
            model.lastError = "QR scanning is not available on this device."
            return
        }
        isShowingTankSetup = false
        isScanningQR = true
    }

    private func handleScan(payload: String) {
        guard let url = URL(string: payload) else { return }
        model.applyTankPayload(from: url)
        isScanningQR = false
        Task { await model.saveTankConnection() }
    }

    private var trimmedSettingsDraft: String {
        settingsDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var privacyDetail: String {
        switch model.profile.privacyComfort {
        case .localFirst: "Your data stays on this iPhone unless you choose otherwise."
        case .tankPreferred: "Private Tank processing is preferred when available."
        case .cloudOk: "Cloud processing may be used when it helps."
        }
    }

    private var communicationDetail: String {
        let length = model.profile.accessibilityPreferences.responseLength.title.lowercased()
        return "\(model.profile.preferredTone.title) tone with \(length) answers."
    }

    private var accessibilityDetail: String {
        model.profile.accessibilityPreferences.prefersVoiceFirst ? "Voice first with adaptive text." : "Text, voice, and response length."
    }

    private var connectionDetail: String {
        model.tankAvailable ? "Tank connected; Apple services managed here." : "This iPhone is active; Tank is not connected."
    }

    private var chatProcessingSummary: String {
        if model.tankAvailable { return "Tank available" }
        return switch model.routingPreferences.tankOfflineBehavior {
        case .useAppleCloud: "Apple Cloud when available"
        case .useNOBScloud: "NOBScloud (Apple Cloud when subscribed)"
        case .queueForTank: "Local until Tank returns"
        case .localOnly: "Local only"
        case .askEachTime: "Local fallback"
        }
    }
}

private struct SettingsSummaryRow: View {
    let symbol: String
    let title: String
    let detail: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.nobsForest)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.nobsInk)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.nobsMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.nobsAccent)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.nobsMuted)
        }
        .frame(minHeight: 74)
        .contentShape(Rectangle())
    }
}

private struct SettingsLinkRow: View {
    let symbol: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Color.nobsForest)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.nobsInk)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(Color.nobsMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 10)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.nobsMuted)
            }
            .frame(minHeight: 68)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
