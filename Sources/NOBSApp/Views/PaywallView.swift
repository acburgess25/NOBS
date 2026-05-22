/// PaywallView — Shown to users whose device doesn't support Apple Intelligence
///
/// Clearly explains what's required and offers the NOBS Server subscription
/// as an alternative so they can still use the full app via Tank's AI.

import SwiftUI
import StoreKit
import NOBSCore

struct PaywallView: View {
    @State private var manager = SubscriptionManager.shared
    @State private var capability = DeviceCapability.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                header
                capabilityCard
                optionsSection
                footer
            }
            .padding(Spacing.lg)
        }
        .background(Color.nobsBg)
        .alert("Error", isPresented: $showError, presenting: manager.errorMessage) { _ in
            Button("OK") {}
        } message: { msg in Text(msg) }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.md) {
            NobsLogo(size: 72)
                .padding(.top, Spacing.xl)

            Text("NOBS AI")
                .font(NOBSFont.display())
                .foregroundStyle(Color.nobsPrimary)

            Text("Private. Fast. Yours.")
                .font(NOBSFont.body())
                .foregroundStyle(Color.nobsSecondary)
        }
    }

    // MARK: - Capability Card

    private var capabilityCard: some View {
        NOBSCard {
            HStack(spacing: Spacing.md) {
                Image(systemName: capability.statusIcon)
                    .font(.system(size: 22))
                    .foregroundStyle(
                        capability.supportsAppleIntelligence ? Color.nobsAccent : Color.nobsRed
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(capability.statusTitle)
                        .font(NOBSFont.body())
                        .foregroundStyle(Color.nobsPrimary)
                    Text(capability.statusSubtitle)
                        .font(NOBSFont.caption())
                        .foregroundStyle(Color.nobsSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(spacing: Spacing.md) {
            // On-device option (greyed out if not supported)
            optionCard(
                icon: "cpu.fill",
                iconColor: capability.appleIntelligenceReady ? .nobsGreen : .nobsTertiary,
                title: "Apple Intelligence",
                subtitle: "Free • Runs entirely on iPhone 15 Pro, 15 Pro Max, or iPhone 16+",
                badge: capability.appleIntelligenceReady ? "Active" : "Requires newer iPhone",
                badgeColor: capability.appleIntelligenceReady ? .nobsGreen : .nobsTertiary
            )

            // Divider
            HStack {
                Rectangle().fill(Color.nobsTertiary.opacity(0.3)).frame(height: 1)
                Text("OR").font(NOBSFont.caption(11)).foregroundStyle(Color.nobsTertiary)
                Rectangle().fill(Color.nobsTertiary.opacity(0.3)).frame(height: 1)
            }

            // Server subscription option
            VStack(spacing: Spacing.md) {
                optionCard(
                    icon: "server.rack",
                    iconColor: .nobsAccent,
                    title: "NOBS Server",
                    subtitle: "AI runs on your personal home server — still private, no big tech cloud",
                    badge: manager.isSubscribed ? "Active" : "Subscription",
                    badgeColor: manager.isSubscribed ? .nobsGreen : .nobsAccent
                )

                if !manager.isSubscribed {
                    serverPricingCards
                    restoreButton
                }
            }
        }
    }

    private var serverPricingCards: some View {
        VStack(spacing: Spacing.sm) {
            // Monthly
            if let monthly = manager.monthlyProduct {
                PriceRow(
                    product: monthly,
                    label: "Monthly",
                    sublabel: "\(monthly.displayPrice)/month",
                    isPopular: false
                ) {
                    await purchase(monthly)
                }
            }

            // Yearly (popular)
            if let yearly = manager.yearlyProduct {
                PriceRow(
                    product: yearly,
                    label: "Yearly",
                    sublabel: "\(yearly.displayPrice)/year · Best value",
                    isPopular: true
                ) {
                    await purchase(yearly)
                }
            }

            // Placeholder while loading
            if manager.isLoading {
                ProgressView().padding()
            }
        }
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await manager.restorePurchases() }
        }
        .font(NOBSFont.caption())
        .foregroundStyle(Color.nobsSecondary)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            Text("What is NOBS Server?")
                .font(NOBSFont.body())
                .foregroundStyle(Color.nobsPrimary)
            Text("NOBS Server runs open-source AI on a home server you own. Your data never touches Apple, Anthropic, OpenAI, or any third-party cloud. You're the only one with access.")
                .font(NOBSFont.caption())
                .foregroundStyle(Color.nobsSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            HStack(spacing: Spacing.lg) {
                Label("No big tech", systemImage: "xmark.shield.fill")
                Label("Cancel anytime", systemImage: "checkmark.circle.fill")
                Label("Your server", systemImage: "house.fill")
            }
            .font(NOBSFont.caption(11))
            .foregroundStyle(Color.nobsTertiary)
            .padding(.bottom, Spacing.xl)
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Helpers

    private func optionCard(icon: String, iconColor: Color, title: String, subtitle: String, badge: String, badgeColor: Color) -> some View {
        NOBSCard {
            HStack(alignment: .top, spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(NOBSFont.body())
                        .foregroundStyle(Color.nobsPrimary)
                    Text(subtitle)
                        .font(NOBSFont.caption())
                        .foregroundStyle(Color.nobsSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                NOBSTag(text: badge, color: badgeColor)
            }
        }
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        let success = await manager.purchase(product)
        isPurchasing = false
        if success { dismiss() }
        else if manager.errorMessage != nil { showError = true }
    }
}

// MARK: - Price Row

private struct PriceRow: View {
    let product: Product
    let label: String
    let sublabel: String
    let isPopular: Bool
    let onPurchase: () async -> Void

    @State private var isLoading = false

    var body: some View {
        Button {
            Task {
                isLoading = true
                await onPurchase()
                isLoading = false
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        Text(label).font(NOBSFont.body()).foregroundStyle(Color.nobsPrimary)
                        if isPopular {
                            NOBSTag(text: "Popular", color: .nobsAccent)
                        }
                    }
                    Text(sublabel).font(NOBSFont.caption()).foregroundStyle(Color.nobsSecondary)
                }
                Spacer()
                if isLoading {
                    ProgressView().tint(Color.nobsAccent)
                } else {
                    Text("Subscribe")
                        .font(NOBSFont.caption())
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs + 2)
                        .background(Color.nobsAccent)
                        .clipShape(Capsule())
                }
            }
            .padding(Spacing.md)
            .background(isPopular ? Color.nobsAccent.opacity(0.06) : Color.nobsCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(isPopular ? Color.nobsAccent.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
