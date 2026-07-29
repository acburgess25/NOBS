import Foundation
import StoreKit

@MainActor
final class StoreKitService: ObservableObject {
    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case succeeded(String)
        case failed(String)
    }

    @Published private(set) var tipProducts: [Product] = []
    @Published private(set) var nobscloudProduct: Product?
    @Published private(set) var hasNOBScloud = false
    @Published private(set) var isLoading = false
    @Published private(set) var loadFailed = false
    @Published var purchaseState: PurchaseState = .idle

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await Product.products(for: StoreProducts.allIDs)
            tipProducts = loaded
                .filter { StoreProducts.tipIDs.contains($0.id) }
                .sorted { $0.price < $1.price }
            nobscloudProduct = loaded.first { $0.id == StoreProducts.nobscloudMonthly }
            loadFailed = false
            await updateEntitlements()
        } catch {
            // A load failure is not a purchase failure — routing it through
            // `purchaseState` would pop the purchase-result alert every time
            // this view appears before products exist in App Store Connect.
            loadFailed = true
        }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseState = .failed("Purchase could not be verified.")
                    return
                }
                await transaction.finish()
                await updateEntitlements()
                purchaseState = .succeeded(successMessage(for: product))
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .succeeded("Purchase is pending approval.")
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateEntitlements()
            let message = hasNOBScloud
                ? "NOBScloud subscription restored."
                : "Purchases restored. Tips do not unlock features; check subscriptions if you joined NOBScloud early."
            purchaseState = .succeeded(message)
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func clearPurchaseState() {
        purchaseState = .idle
    }

    private func successMessage(for product: Product) -> String {
        if product.id == StoreProducts.nobscloudMonthly {
            return "Thank you for NOBScloud. When Tank is away, subscribed capacity can use Apple private cloud where available. Core local features stay free."
        }
        return "Thank you for supporting NOBS."
    }

    private func updateEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == StoreProducts.nobscloudMonthly else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < .now {
                continue
            }
            active = true
        }
        hasNOBScloud = active
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
            await updateEntitlements()
        }
    }
}
