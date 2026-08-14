import StoreKit
import SwiftUI

struct SupportView: View {
    @EnvironmentObject private var store: StoreKitService
    private let accent = Color.nobsAccent

    var body: some View {
        Section {
            if store.isLoading && store.tipProducts.isEmpty && store.nobscloudProduct == nil {
                ProgressView("Loading App Store offers…")
            } else if store.tipProducts.isEmpty && store.nobscloudProduct == nil {
                emptyState
            } else {
                tipButtons
                subscriptionRow
                Button("Restore purchases") {
                    Task { await store.restorePurchases() }
                }
            }
        } header: {
            Text("Support NOBS")
        } footer: {
            Text("Tips fund open development through Apple In-App Purchase. They do not unlock features. NOBScloud unlocks Apple private cloud fallback when Tank is away and your device supports it. Local briefing and Tank stay free.")
        }
        .task {
            await store.refresh()
        }
        .alert("Support", isPresented: purchaseAlertBinding) {
            Button("OK") { store.clearPurchaseState() }
        } message: {
            Text(purchaseAlertMessage)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.hasNOBScloud {
                Text("NOBScloud is active — thank you. Support options are still loading.")
                    .font(.footnote)
                    .foregroundStyle(accent)
            }
            if store.loadFailed {
                Text("Couldn't load support options from the App Store right now. This may be a connection issue or a temporary App Store problem.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try again") {
                    Task { await store.refresh() }
                }
                .font(.footnote)
            } else if !store.hasNOBScloud {
                Text("Tips and NOBScloud aren't turned on for this build yet — coming soon. Everything else in NOBS stays free either way.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var tipButtons: some View {
        ForEach(store.tipProducts, id: \.id) { product in
            Button {
                Task { await store.purchase(product) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tipTitle(for: product))
                            .font(.body.weight(.medium))
                        Text("One-time tip via Apple")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(product.displayPrice)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }
            .disabled(store.purchaseState == .purchasing)
        }
    }

    @ViewBuilder
    private var subscriptionRow: some View {
        if let product = store.nobscloudProduct {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOBScloud Monthly")
                            .font(.body.weight(.medium))
                        Text(store.hasNOBScloud ? "Active — thank you" : "Paid Apple Cloud fallback when Tank is away")
                            .font(.caption)
                            .foregroundStyle(store.hasNOBScloud ? accent : .secondary)
                    }
                    Spacer()
                    Text(product.displayPrice)
                        .font(.body.weight(.semibold))
                }

                if !store.hasNOBScloud {
                    Button("Subscribe with Apple") {
                        Task { await store.purchase(product) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(store.purchaseState == .purchasing)
                }

                Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(.footnote)
            }
            .padding(.vertical, 4)
        }
    }

    private func tipTitle(for product: Product) -> String {
        switch product.id {
        case StoreProducts.tipSmall: "Small tip"
        case StoreProducts.tipMedium: "Medium tip"
        case StoreProducts.tipLarge: "Large tip"
        default: product.displayName
        }
    }

    private var purchaseAlertBinding: Binding<Bool> {
        Binding(
            get: {
                switch store.purchaseState {
                case .succeeded, .failed: true
                default: false
                }
            },
            set: { isPresented in
                if !isPresented { store.clearPurchaseState() }
            }
        )
    }

    private var purchaseAlertMessage: String {
        switch store.purchaseState {
        case .succeeded(let message): message
        case .failed(let message): message
        default: ""
        }
    }
}
