import Foundation
import StoreKit

/// Tracks VaultyPro Pro entitlement via StoreKit 2 and gates premium features.
@MainActor
@Observable
final class ProStatusManager {
    /// True when an active StoreKit entitlement is present.
    private(set) var entitled: Bool = false
    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    var purchaseError: String?

    /// Whether the user has Pro access. In DEBUG builds a manual override can unlock it
    /// for testing without a real purchase.
    var isPro: Bool {
        #if DEBUG
        return entitled || debugProUnlocked
        #else
        return entitled
        #endif
    }

    #if DEBUG
    /// Developer-only unlock, persisted across launches. Toggle it from Settings.
    var debugProUnlocked: Bool = UserDefaults.standard.bool(forKey: "debug.proUnlocked") {
        didSet { UserDefaults.standard.set(debugProUnlocked, forKey: "debug.proUnlocked") }
    }
    #endif

    private var updatesTask: Task<Void, Never>?
    private let productIDs = [AppConfig.Product.monthly, AppConfig.Product.annual]

    init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    var monthlyProduct: Product? { products.first { $0.id == AppConfig.Product.monthly } }
    var annualProduct: Product? { products.first { $0.id == AppConfig.Product.annual } }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: productIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            // No StoreKit configuration during development — leave products empty.
            products = []
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        entitled = active
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
