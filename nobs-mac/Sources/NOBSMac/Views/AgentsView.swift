import SwiftUI

struct AgentsView: View {
    @Environment(CommandCenterStore.self) private var store
    @State private var hasOwnComputer = true
    @State private var allowTankBeta = true
    @State private var offlineBluetooth = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(
                    title: "Agents",
                    subtitle: "Choose where NOBS should run work: local machine first, Tank for beta hosting, and phone-only fallback when disconnected."
                )

                HardwareRecommendationPanel(profile: store.hardwareProfile)

                GlassPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        Toggle(isOn: $hasOwnComputer) {
                            Label("I have my own MacBook or Linux box", systemImage: "desktopcomputer")
                        }

                        Toggle(isOn: $allowTankBeta) {
                            Label("Use Tank free during beta", systemImage: "server.rack")
                        }

                        Toggle(isOn: $offlineBluetooth) {
                            Label("Work locally over Bluetooth when there is no connection", systemImage: "dot.radiowaves.left.and.right")
                        }
                    }
                    .toggleStyle(.switch)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                    RuntimeCard(
                        title: "Own MacBook",
                        subtitle: "Best default. Wake services only while work is running, then shut them down cleanly.",
                        symbolName: "macbook",
                        tint: .blue
                    )
                    RuntimeCard(
                        title: "Own Linux Box",
                        subtitle: "Good for always-available local compute without depending on paid cloud services.",
                        symbolName: "terminal",
                        tint: .sage
                    )
                    RuntimeCard(
                        title: "Tank Beta",
                        subtitle: "Free beta access to your server for testers who need hosted agent runtime.",
                        symbolName: "externaldrive.badge.icloud",
                        tint: .amber
                    )
                    RuntimeCard(
                        title: "Phone Local",
                        subtitle: "When offline, keep the experience useful with on-device state and Bluetooth relay.",
                        symbolName: "iphone.radiowaves.left.and.right",
                        tint: .graphite
                    )
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct HardwareRecommendationPanel: View {
    let profile: HardwareProfile

    var body: some View {
        let recommendation = profile.recommendation

        GlassPanel {
            HStack(alignment: .top, spacing: 18) {
                Image(systemName: recommendation.route.symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(recommendation.route.tint.color)
                    .frame(width: 54, height: 54)
                    .background(recommendation.route.tint.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendation.title)
                                .font(.title3.weight(.semibold))
                            Text("\(profile.chipName) · \(profile.memoryGB) GB memory · \(profile.cpuCores) CPU cores")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(profile.localScore)% local fit")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(recommendation.route.tint.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(recommendation.route.tint.color.opacity(0.12), in: Capsule())
                    }

                    Text(recommendation.summary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    Label(recommendation.nextStep, systemImage: "lightbulb")
                        .font(.callout)
                }
            }
        }
    }
}

private struct RuntimeCard: View {
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: NOBSTint

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint.color)
                    .frame(width: 42, height: 42)
                    .background(tint.color.opacity(0.12), in: Circle())

                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
