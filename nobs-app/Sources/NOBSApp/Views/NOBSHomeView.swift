import SwiftUI
import NOBSCore

struct NOBSHomeView: View {
    @StateObject private var capability = DeviceCapability.shared
    @AppStorage("local_mode_enabled") private var localModeEnabled = true
    @AppStorage("icloud_sync_enabled") private var iCloudSyncEnabled = false
    @AppStorage("nobs_family_mode") private var familyMode = false
    @AppStorage("tank_beta_enabled") private var tankBetaEnabled = false
    @State private var notificationStatus = "Not enabled"
    @State private var isRequestingNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    hero
                    routingPanel
                    quickActions
                    privacyPanel
                    familyPanel
                }
                .padding(Spacing.md)
            }
            .background(Color.nobsBg)
            .navigationTitle("NOBS")
            .task { await refreshNotificationStatus() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                NobsLogo(size: 54)
                    .nobsShadow(strong: true)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Private Apple AI")
                        .font(NOBSFont.title2())
                        .foregroundStyle(Color.nobsPrimary)
                    Text("Local first. Tank when needed. Every step asks before it reaches outside your device.")
                        .font(NOBSFont.callout())
                        .foregroundStyle(Color.nobsSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: Spacing.sm) {
                NOBSTag(text: localModeEnabled ? "LOCAL" : "SIGNED IN", color: .nobsGreen)
                NOBSTag(text: iCloudSyncEnabled ? "ICLOUD SYNC" : "NO CLOUD", color: .nobsBlue)
                NOBSTag(text: tankBetaEnabled ? "TANK READY" : "ON DEVICE", color: .nobsAccent)
            }
        }
        .padding(Spacing.md)
        .glassEffect(in: RoundedRectangle(cornerRadius: Radius.xxl, style: .continuous))
    }

    private var routingPanel: some View {
        NOBSCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Runtime Route", systemImage: capability.statusIcon)
                    .font(NOBSFont.headline())
                    .foregroundStyle(Color.nobsPrimary)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(capability.statusTitle)
                        .font(NOBSFont.title3())
                        .foregroundStyle(Color.nobsPrimary)
                    Text(runtimeSubtitle)
                        .font(NOBSFont.callout())
                        .foregroundStyle(Color.nobsSecondary)
                }

                Divider()

                Toggle(isOn: $tankBetaEnabled) {
                    Label("Use Tank when this iPhone needs help", systemImage: "server.rack")
                }
                .font(NOBSFont.body())

                Text("Tank should wake on demand from a Mac mini, MacBook, Linux box, or your beta server. If it is offline, NOBS stays local.")
                    .font(NOBSFont.caption())
                    .foregroundStyle(Color.nobsTertiary)
            }
        }
    }

    private var runtimeSubtitle: String {
        if capability.supportsAppleIntelligence && capability.appleIntelligenceReady {
            return "This iPhone can run the private on-device route first."
        }
        return "This iPhone should use local tools first, then ask for Tank, a home server, or subscription compute."
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Set Up")
                .font(NOBSFont.overline())
                .foregroundStyle(Color.nobsTertiary)

            VStack(spacing: Spacing.sm) {
                actionRow(
                    icon: "bell.badge.fill",
                    title: "Notifications",
                    detail: notificationStatus,
                    buttonTitle: "Enable"
                ) {
                    requestNotifications()
                }

                actionRow(
                    icon: "sparkles",
                    title: "30-minute Apple interview",
                    detail: "Turn your Apple apps, family devices, and Tank options into a daily plan.",
                    buttonTitle: "Start"
                ) {
                    UserDefaults.standard.set(3, forKey: "onboarding_start_step")
                    UserDefaults.standard.set(false, forKey: "onboarding_complete")
                }
            }
        }
    }

    private var privacyPanel: some View {
        NOBSCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Consent Ledger", systemImage: "checkmark.shield.fill")
                    .font(NOBSFont.headline())
                    .foregroundStyle(Color.nobsPrimary)

                settingLine(icon: "iphone", title: "Local memory", value: "On")
                settingLine(icon: "icloud", title: "iCloud sync", value: iCloudSyncEnabled ? "Encrypted" : "Off")
                settingLine(icon: "person.crop.circle.badge.checkmark", title: "Account", value: localModeEnabled ? "Not required" : "Apple ID")
                settingLine(icon: "wrench.and.screwdriver", title: "Public tools", value: "Review before use")
            }
        }
    }

    private var familyPanel: some View {
        NOBSCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("Family Guardrails", systemImage: "figure.2.and.child.holdinghands")
                    .font(NOBSFont.headline())
                    .foregroundStyle(Color.nobsPrimary)

                Toggle(isOn: $familyMode) {
                    Text("Prepare family accounts")
                }
                .font(NOBSFont.body())

                Text("Adults keep private encrypted spaces. Kids and teens get educational and wellbeing guardrails that an admin explicitly approves.")
                    .font(NOBSFont.callout())
                    .foregroundStyle(Color.nobsSecondary)
            }
        }
    }

    private func actionRow(
        icon: String,
        title: String,
        detail: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.nobsAccent)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(Color.nobsAccent), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NOBSFont.headline())
                    .foregroundStyle(Color.nobsPrimary)
                Text(detail)
                    .font(NOBSFont.caption())
                    .foregroundStyle(Color.nobsSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(buttonTitle, action: action)
                .font(NOBSFont.caption())
                .buttonStyle(.glass)
                .disabled(isRequestingNotifications && title == "Notifications")
        }
        .padding(Spacing.md)
        .glassEffect(in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private func settingLine(icon: String, title: String, value: String) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .foregroundStyle(Color.nobsAccent)
                .frame(width: 22)
            Text(title)
                .font(NOBSFont.body())
                .foregroundStyle(Color.nobsPrimary)
            Spacer()
            Text(value)
                .font(NOBSFont.caption())
                .foregroundStyle(Color.nobsSecondary)
        }
    }

    private func requestNotifications() {
        isRequestingNotifications = true
        Task {
            let granted = await NOBSNotificationManager.shared.requestPermission()
            notificationStatus = granted ? "Enabled" : "Not enabled"
            isRequestingNotifications = false
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await NOBSNotificationManager.shared.authorizationStatusText()
    }
}
