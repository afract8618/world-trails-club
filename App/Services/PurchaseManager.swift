import Foundation
import StoreKit
import Observation

/// StoreKit 2 wrapper for World Trails Club Plus.
///
/// Requires setup (see README → "Purchases"): the three product IDs below must exist in
/// App Store Connect (or in a local StoreKit configuration file for simulator testing).
@MainActor
@Observable
final class PurchaseManager {
    enum ProductID {
        static let monthly = "club.plus.monthly"
        static let annual = "club.plus.annual"
        static let lifetime = "club.plus.lifetime"
        static let all = [monthly, annual, lifetime]
    }

    enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

    private(set) var products: [Product] = []
    private(set) var loadState: LoadState = .idle
    private(set) var isPlus = false
    private(set) var activeProductID: String?
    private(set) var isPurchasing = false
    @ObservationIgnored var onEvent: ((PurchaseEvent) -> Void)?

    enum PurchaseEvent {
        case started(String), completed(String, isTrial: Bool), failed(String, String), restored(String), statusChanged(String, String)
    }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.refreshEntitlements()
                    self.onEvent?(.statusChanged(transaction.productID, transaction.revocationDate == nil ? "active" : "revoked"))
                }
            }
        }
    }

    func loadProducts() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded.sorted { order($0.id) < order($1.id) }
            loadState = loaded.isEmpty ? .failed("Membership options aren't available right now.") : .loaded
        } catch {
            loadState = .failed("Couldn't reach the App Store. Check your connection and try again.")
        }
    }

    private func order(_ id: String) -> Int { ProductID.all.firstIndex(of: id) ?? 99 }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        onEvent?(.started(product.id))
        do {
            let result = try await product.purchase()
            switch result {
            case .success(.verified(let transaction)):
                let isTrial = transaction.offerType == .introductory
                await transaction.finish()
                await refreshEntitlements()
                onEvent?(.completed(product.id, isTrial: isTrial))
            case .success(.unverified(_, let error)):
                onEvent?(.failed(product.id, "unverified: \(error)"))
            case .userCancelled:
                onEvent?(.failed(product.id, "cancelled"))
            case .pending:
                onEvent?(.failed(product.id, "pending"))
            @unknown default:
                onEvent?(.failed(product.id, "unknown"))
            }
        } catch {
            onEvent?(.failed(product.id, error.localizedDescription))
        }
    }

    /// "Restore Purchases" — required by App Review for non-consumables/subscriptions.
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
        if let id = activeProductID { onEvent?(.restored(id)) }
    }

    func refreshEntitlements() async {
        var active: String?
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let t) = entitlement, ProductID.all.contains(t.productID), t.revocationDate == nil {
                if let expiry = t.expirationDate, expiry < Date() { continue }
                active = t.productID
            }
        }
        activeProductID = active
        isPlus = active != nil
    }
}
