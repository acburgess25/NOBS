import SwiftUI
import StoreKit

struct AgencyPaywallView: View {
    let auth: APIClient
    @State private var manager = SubscriptionManager.shared
    @State private var purchasing: AgencyTier? = nil
    @State private var showError = false
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss

    private let tiers: [AgencyTier] = [.starter, .growth, .premium]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                header
                if manager.hasAgencyAccess {
                    activeCard
                } else {
                    tierCards
                    restoreButton
                }
                footer
            }
            .padding(Spacing.lg)
        }
        .background(Color.nobsBg)
        .alert("Error", isPresented: $showError, presenting: manager.errorMessage) { _ in
            Button("OK") {}
        } message: { msg in Text(msg) }
        .alert("Agency Unlocked", isPresented: $showSuccess) {
            Button("Open Agency") { openAgencyPortal() }
            Button("Done") { dismiss() }
        } message: {
            Text("Your agency subscription is active. Open the portal to start managing clients.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(Color.nobsAccent)
                .padding(.top, Spacing.xl)

            Text("NOBS Agency")
                .font(NOBSFont.display())
                .foregroundStyle(Color.nobsPrimary)

            Text("AI-powered social media management, running on your Tank server.")
                .font(NOBSFont.caption())
                .foregroundStyle(Color.nobsSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Active State

    private var activeCard: some View {
        NOBSCard {
            VStack(spacing: Spacing.md) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.nobsGreen)
                    Text("\(manager.agencyTier?.displayName ?? "") Plan — Active")
                        .font(NOBSFont.body())
                        .foregroundStyle(Color.nobsPrimary)
                    Spacer()
                    NOBSTag(text: "Active", color: .nobsGreen)
                }

                Divider().background(Color.nobsTertiary.opacity(0.3))

                Button {
                    openAgencyPortal()
                } label: {
                    HStack {
                        Text("Open Agency Portal")
                            .font(NOBSFont.body())
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .foregroundStyle(Color.nobsAccent)
                }
            }
        }
    }

    // MARK: - Tier Cards

    private var tierCards: some View {
        VStack(spacing: Spacing.md) {
            ForEach(tiers, id: \.rawValue) { tier in
                TierCard(
                    tier: tier,
                    product: manager.agencyProduct(for: tier),
                    isPopular: tier == .growth,
                    isPurchasing: purchasing == tier
                ) {
                    await purchase(tier)
                }
            }

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
            Label("Runs on your Tank server — no third-party cloud", systemImage: "house.fill")
            Label("AI-generated content for all major platforms", systemImage: "sparkles")
            Label("CEO agent reviews and improves every output", systemImage: "person.badge.shield.checkmark.fill")
        }
        .font(NOBSFont.caption(11))
        .foregroundStyle(Color.nobsTertiary)
        .padding(.bottom, Spacing.xl)
    }

    // MARK: - Actions

    private func purchase(_ tier: AgencyTier) async {
        guard let product = manager.agencyProduct(for: tier) else { return }
        purchasing = tier
        let success = await manager.purchase(product)
        purchasing = nil
        guard success else {
            if manager.errorMessage != nil { showError = true }
            return
        }
        try? await auth.syncAgencySubscription(tier: tier)
        await manager.refreshAgencyStatus()
        showSuccess = true
    }

    private func openAgencyPortal() {
        if let url = URL(string: "https://nobsdash.com/agency") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Tier Card

private struct TierCard: View {
    let tier: AgencyTier
    let product: Product?
    let isPopular: Bool
    let isPurchasing: Bool
    let onPurchase: () async -> Void

    var body: some View {
        NOBSCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Spacing.sm) {
                            Text(tier.displayName)
                                .font(NOBSFont.body())
                                .foregroundStyle(Color.nobsPrimary)
                            if isPopular {
                                NOBSTag(text: "Popular", color: .nobsAccent)
                            }
                        }
                        Text(product?.displayPrice.appending("/mo") ?? "—")
                            .font(NOBSFont.caption())
                            .foregroundStyle(Color.nobsSecondary)
                    }
                    Spacer()
                    purchaseButton
                }

                Divider().background(Color.nobsTertiary.opacity(0.2))

                HStack(spacing: Spacing.lg) {
                    Label("\(tier.postsPerMonth) posts/mo", systemImage: "doc.text.fill")
                    Label(tier.platforms, systemImage: "square.stack.3d.up.fill")
                }
                .font(NOBSFont.caption(11))
                .foregroundStyle(Color.nobsSecondary)
            }
        }
        .background(isPopular ? Color.nobsAccent.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(isPopular ? Color.nobsAccent.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }

    private var purchaseButton: some View {
        Button {
            Task { await onPurchase() }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Subscribe")
                }
            }
            .font(NOBSFont.caption())
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs + 2)
            .background(Color.nobsAccent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || product == nil)
    }
}