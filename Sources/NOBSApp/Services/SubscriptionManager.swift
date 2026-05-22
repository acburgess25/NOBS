/// SubscriptionManager — StoreKit 2 subscription for NOBS Server
///
/// Manages the "NOBS Server" monthly subscription that gives users
/// on older iPhones (or those who prefer it) access to Tank's Ollama.
/// Modern iPhones (15 Pro+, 16+) get full on-device AI for free.

import StoreKit
import Observation

// MARK: - Product IDs

private enum ProductID {
    static let serverMonthly = "ai.nobs.server.monthly"
    static let serverYearly  = "ai.nobs.server.yearly"
}

// MARK: - SubscriptionManager

@MainActor
@Observable
public final class SubscriptionManager {

    public static let shared = SubscriptionManager()

    // MARK: State
    public var products: [Product] = []
    public var isSubscribed: Bool = false
    public var isLoading: Bool = false
    public var errorMessage: String?

    nonisolated(unsafe) private var updateListenerTask: Task<Void, Error>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshSubscriptionStatus() }
    }

    deinit { updateListenerTask?.cancel() }

    // MARK: - Load Products

    public func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: [
                ProductID.serverMonthly,
                ProductID.serverYearly
            ])
            .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Couldn't load subscription options: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Purchase

    public func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshSubscriptionStatus()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    public func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            errorMessage = "Couldn't restore purchases: \(error.localizedDescription)"
        }
    }

    // MARK: - Subscription check

    public func refreshSubscriptionStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == ProductID.serverMonthly ||
               transaction.productID == ProductID.serverYearly {
                active = transaction.revocationDate == nil
            }
        }
        isSubscribed = active
    }

    // MARK: - Transaction listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.refreshSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed: \(error)")
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let item): return item
        }
    }
}

// MARK: - Convenience

public extension SubscriptionManager {
    var monthlyProduct: Product? { products.first { $0.id == ProductID.serverMonthly } }
    var yearlyProduct: Product?  { products.first { $0.id == ProductID.serverYearly  } }

    var monthlyPriceString: String { monthlyProduct?.displayPrice ?? "$4.99" }
    var yearlyPriceString: String  { yearlyProduct?.displayPrice  ?? "$39.99" }
}
