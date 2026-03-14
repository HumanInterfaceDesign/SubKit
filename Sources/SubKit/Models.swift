import Foundation
import StoreKit

public enum EntitlementKind: String, Sendable {
    case oneOffPurchase
    case subscription
}

public enum PurchaseSource: String, Sendable {
    case inApp
    case purchaseIntent
    case external
}

public struct Entitlement: Identifiable, Sendable {
    public let productID: Product.ID
    public let kind: EntitlementKind
    public let transactionID: UInt64
    public let originalTransactionID: UInt64
    public let purchaseDate: Date
    public let originalPurchaseDate: Date
    public let expirationDate: Date?
    public let revocationDate: Date?
    public let isUpgraded: Bool
    public let appAccountToken: UUID?
    public let transaction: Transaction
    public let jwsRepresentation: String

    public var id: Product.ID {
        self.productID
    }
}

public struct SuccessfulPurchase: Sendable {
    public let source: PurchaseSource
    public let productID: Product.ID
    public let transactionID: UInt64
    public let originalTransactionID: UInt64
    public let purchaseDate: Date
    public let appAccountToken: UUID?
    public let transaction: Transaction
    public let jwsRepresentation: String
}

public enum PurchaseResult: Sendable {
    case success(SuccessfulPurchase)
    case pending(productID: Product.ID, source: PurchaseSource)
    case userCancelled(productID: Product.ID, source: PurchaseSource)
}

public struct SubscriptionStatus: Identifiable, Sendable {
    public let groupID: String
    public let productID: Product.ID
    public let state: Product.SubscriptionInfo.RenewalState
    public let transactionID: UInt64
    public let originalTransactionID: UInt64
    public let transaction: Transaction
    public let transactionJWS: String
    public let renewalInfo: Product.SubscriptionInfo.RenewalInfo
    public let renewalInfoJWS: String

    public var id: String {
        "\(self.groupID)::\(self.transactionID)"
    }
}

public struct Snapshot: Sendable {
    public let products: [Product]
    public let entitlements: [Entitlement]
    public let subscriptionStatusesByGroupID: [String: [SubscriptionStatus]]
}

extension Entitlement {
    init(result: VerificationResult<Transaction>) throws {
        let transaction = try Self.verify(result)

        self.productID = transaction.productID
        self.kind = try Self.kind(for: transaction)
        self.transactionID = transaction.id
        self.originalTransactionID = transaction.originalID
        self.purchaseDate = transaction.purchaseDate
        self.originalPurchaseDate = transaction.originalPurchaseDate
        self.expirationDate = transaction.expirationDate
        self.revocationDate = transaction.revocationDate
        self.isUpgraded = transaction.isUpgraded
        self.appAccountToken = transaction.appAccountToken
        self.transaction = transaction
        self.jwsRepresentation = result.jwsRepresentation
    }

    static func verify(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case let .verified(transaction):
            return transaction
        case let .unverified(transaction, error):
            throw SubKitError.failedVerification(
                productID: transaction.productID,
                jwsRepresentation: result.jwsRepresentation,
                reason: String(describing: error)
            )
        }
    }

    private static func kind(for transaction: Transaction) throws -> EntitlementKind {
        switch transaction.productType {
        case .autoRenewable:
            return .subscription
        case .nonConsumable:
            return .oneOffPurchase
        default:
            throw SubKitError.unsupportedProductType(
                productID: transaction.productID,
                type: transaction.productType
            )
        }
    }
}

extension SuccessfulPurchase {
    init(result: VerificationResult<Transaction>, source: PurchaseSource) throws {
        let transaction = try Entitlement.verify(result)

        self.source = source
        self.productID = transaction.productID
        self.transactionID = transaction.id
        self.originalTransactionID = transaction.originalID
        self.purchaseDate = transaction.purchaseDate
        self.appAccountToken = transaction.appAccountToken
        self.transaction = transaction
        self.jwsRepresentation = result.jwsRepresentation
    }
}

extension SubscriptionStatus {
    init(groupID: String, status: Product.SubscriptionInfo.Status) throws {
        let transaction = try Entitlement.verify(status.transaction)
        let renewalInfo = try Self.verify(status.renewalInfo, productID: transaction.productID)

        self.groupID = groupID
        self.productID = renewalInfo.currentProductID
        self.state = status.state
        self.transactionID = transaction.id
        self.originalTransactionID = transaction.originalID
        self.transaction = transaction
        self.transactionJWS = status.transaction.jwsRepresentation
        self.renewalInfo = renewalInfo
        self.renewalInfoJWS = status.renewalInfo.jwsRepresentation
    }

    private static func verify(
        _ result: VerificationResult<Product.SubscriptionInfo.RenewalInfo>,
        productID: Product.ID
    ) throws -> Product.SubscriptionInfo.RenewalInfo {
        switch result {
        case let .verified(renewalInfo):
            return renewalInfo
        case let .unverified(_, error):
            throw SubKitError.failedVerification(
                productID: productID,
                jwsRepresentation: result.jwsRepresentation,
                reason: String(describing: error)
            )
        }
    }
}
