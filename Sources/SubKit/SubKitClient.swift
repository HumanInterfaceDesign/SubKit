import Foundation
import StoreKit

#if canImport(UIKit)
import UIKit
#endif

public actor SubKitClient {
    public let configuration: Configuration

    private var productsByID: [Product.ID: Product] = [:]
    private var entitlementsByProductID: [Product.ID: Entitlement] = [:]
    private var subscriptionStatusesByGroupID: [String: [SubscriptionStatus]] = [:]
    private var transactionUpdatesTask: Task<Void, Never>?

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.transactionUpdatesTask = nil
    }

    deinit {
        self.transactionUpdatesTask?.cancel()
    }

    public func loadProducts() async throws -> [Product] {
        self.ensureTransactionObserverStarted()
        let products = try await Product.products(for: self.configuration.sortedProductIDs)

        self.productsByID = Dictionary(
            uniqueKeysWithValues: products.map { ($0.id, $0) }
        )

        try await self.refreshCaches()
        return self.loadedProducts()
    }

    public func loadedProducts() -> [Product] {
        self.sortedProducts(Array(self.productsByID.values))
    }

    public func refresh() async throws -> Snapshot {
        self.ensureTransactionObserverStarted()
        try await self.refreshCaches()
        return self.snapshot()
    }

    public func snapshot() -> Snapshot {
        Snapshot(
            products: self.loadedProducts(),
            entitlements: self.sortedEntitlements(Array(self.entitlementsByProductID.values)),
            subscriptionStatusesByGroupID: self.sortedSubscriptionStatuses(self.subscriptionStatusesByGroupID)
        )
    }

    public func currentEntitlements() async throws -> [Entitlement] {
        self.ensureTransactionObserverStarted()
        try await self.refreshEntitlements()
        return self.sortedEntitlements(Array(self.entitlementsByProductID.values))
    }

    public func subscriptionStatuses(groupID: String) async throws -> [SubscriptionStatus] {
        self.ensureTransactionObserverStarted()
        let statuses = try await self.fetchSubscriptionStatuses(for: groupID)
        self.subscriptionStatusesByGroupID[groupID] = statuses
        return statuses
    }

    public func allSubscriptionStatuses() async throws -> [String: [SubscriptionStatus]] {
        self.ensureTransactionObserverStarted()
        for groupID in self.configuration.sortedSubscriptionGroupIDs {
            self.subscriptionStatusesByGroupID[groupID] = try await self.fetchSubscriptionStatuses(for: groupID)
        }
        return self.sortedSubscriptionStatuses(self.subscriptionStatusesByGroupID)
    }

    public func syncPurchases() async throws -> [Entitlement] {
        self.ensureTransactionObserverStarted()
        try await AppStore.sync()
        return try await self.currentEntitlements()
    }

    public func purchase(
        productID: Product.ID,
        appAccountToken: UUID? = nil
    ) async throws -> PurchaseResult {
        self.ensureTransactionObserverStarted()
        let product = try await self.product(for: productID)
        try self.ensureSupported(product)

        do {
            let result = try await product.purchase(options: self.purchaseOptions(appAccountToken))
            return try await self.consume(result, fallbackProductID: productID, source: .inApp)
        } catch StoreKitError.userCancelled {
            return .userCancelled(productID: productID, source: .inApp)
        }
    }

    #if canImport(UIKit)
    @available(iOS 17.0, tvOS 15.0, visionOS 1.0, *)
    public func purchase(
        productID: Product.ID,
        appAccountToken: UUID? = nil,
        confirmingIn viewController: UIViewController
    ) async throws -> PurchaseResult {
        self.ensureTransactionObserverStarted()
        let product = try await self.product(for: productID)
        try self.ensureSupported(product)

        do {
            if #available(iOS 18.2, *) {
                let result = try await product.purchase(
                    confirmIn: viewController,
                    options: self.purchaseOptions(appAccountToken)
                )
                return try await self.consume(result, fallbackProductID: productID, source: .inApp)
            } else {
                // Fallback on earlier versions
                fatalError("Add this later.")
            }
        } catch StoreKitError.userCancelled {
            return .userCancelled(productID: productID, source: .inApp)
        }
    }

    @available(iOS 17.0, tvOS 15.0, visionOS 1.0, *)
    public func purchase(
        productID: Product.ID,
        appAccountToken: UUID? = nil,
        confirmingIn scene: UIScene
    ) async throws -> PurchaseResult {
        self.ensureTransactionObserverStarted()
        let product = try await self.product(for: productID)
        try self.ensureSupported(product)

        do {
            let result = try await product.purchase(
                confirmIn: scene,
                options: self.purchaseOptions(appAccountToken)
            )
            return try await self.consume(result, fallbackProductID: productID, source: .inApp)
        } catch StoreKitError.userCancelled {
            return .userCancelled(productID: productID, source: .inApp)
        }
    }
    #endif

    private func refreshCaches() async throws {
        try await self.refreshEntitlements()
        for groupID in self.configuration.sortedSubscriptionGroupIDs {
            self.subscriptionStatusesByGroupID[groupID] = try await self.fetchSubscriptionStatuses(for: groupID)
        }
    }

    private func product(for productID: Product.ID) async throws -> Product {
        if let product = self.productsByID[productID] {
            return product
        }

        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw SubKitError.productNotFound(productID)
        }

        self.productsByID[productID] = product
        return product
    }

    private func refreshEntitlements() async throws {
        var entitlements: [Product.ID: Entitlement] = [:]

        for await result in Transaction.currentEntitlements {
            switch result {
            case let .verified(transaction):
                guard self.configuration.productIDs.contains(transaction.productID) else {
                    continue
                }
                let entitlement = try Entitlement(result: result)
                entitlements[entitlement.productID] = entitlement
            case let .unverified(transaction, error):
                guard self.configuration.productIDs.contains(transaction.productID) else {
                    continue
                }
                throw SubKitError.failedVerification(
                    productID: transaction.productID,
                    jwsRepresentation: result.jwsRepresentation,
                    reason: String(describing: error)
                )
            }
        }

        self.entitlementsByProductID = entitlements
    }

    private func fetchSubscriptionStatuses(for groupID: String) async throws -> [SubscriptionStatus] {
        let statuses = try await Product.SubscriptionInfo.status(for: groupID)
        return try statuses
            .map { try SubscriptionStatus(groupID: groupID, status: $0) }
            .sorted { lhs, rhs in
                if lhs.productID == rhs.productID {
                    return lhs.transactionID < rhs.transactionID
                }
                return lhs.productID < rhs.productID
            }
    }

    private func consume(
        _ result: Product.PurchaseResult,
        fallbackProductID: Product.ID,
        source: PurchaseSource
    ) async throws -> PurchaseResult {
        switch result {
        case let .success(verificationResult):
            let purchase = try SuccessfulPurchase(result: verificationResult, source: source)
            try await self.refreshCaches()
            await purchase.transaction.finish()
            return .success(purchase)
        case .pending:
            return .pending(productID: fallbackProductID, source: source)
        case .userCancelled:
            return .userCancelled(productID: fallbackProductID, source: source)
        @unknown default:
            return .pending(productID: fallbackProductID, source: source)
        }
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard !Task.isCancelled else {
                break
            }

            do {
                let purchase = try SuccessfulPurchase(result: result, source: .external)
                guard self.configuration.productIDs.contains(purchase.productID) else {
                    await purchase.transaction.finish()
                    continue
                }

                try await self.refreshCaches()
                await purchase.transaction.finish()
            } catch {
                continue
            }
        }
    }

    private func ensureTransactionObserverStarted() {
        guard self.transactionUpdatesTask == nil else {
            return
        }

        self.transactionUpdatesTask = Task {
            await self.observeTransactionUpdates()
        }
    }

    private func purchaseOptions(_ appAccountToken: UUID?) -> Set<Product.PurchaseOption> {
        guard let appAccountToken else {
            return []
        }
        return [.appAccountToken(appAccountToken)]
    }

    private func ensureSupported(_ product: Product) throws {
        switch product.type {
        case .autoRenewable, .nonConsumable:
            break
        default:
            throw SubKitError.unsupportedProductType(productID: product.id, type: product.type)
        }
    }

    private func sortedProducts(_ products: [Product]) -> [Product] {
        products.sorted { lhs, rhs in
            if lhs.price == rhs.price {
                return lhs.id < rhs.id
            }
            return lhs.price < rhs.price
        }
    }

    private func sortedEntitlements(_ entitlements: [Entitlement]) -> [Entitlement] {
        entitlements.sorted { lhs, rhs in
            if lhs.purchaseDate == rhs.purchaseDate {
                return lhs.productID < rhs.productID
            }
            return lhs.purchaseDate < rhs.purchaseDate
        }
    }

    private func sortedSubscriptionStatuses(
        _ statusesByGroupID: [String: [SubscriptionStatus]]
    ) -> [String: [SubscriptionStatus]] {
        Dictionary(
            uniqueKeysWithValues: statusesByGroupID.map { key, value in
                (
                    key,
                    value.sorted { lhs, rhs in
                        if lhs.productID == rhs.productID {
                            return lhs.transactionID < rhs.transactionID
                        }
                        return lhs.productID < rhs.productID
                    }
                )
            }
        )
    }
}
