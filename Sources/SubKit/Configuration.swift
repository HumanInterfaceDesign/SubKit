import Foundation
import StoreKit

public struct Configuration: Sendable {
    public var productIDs: Set<Product.ID>
    public var subscriptionGroupIDs: Set<String>

    public init(
        productIDs: some Sequence<Product.ID>,
        subscriptionGroupIDs: some Sequence<String> = []
    ) {
        self.productIDs = Set(productIDs)
        self.subscriptionGroupIDs = Set(subscriptionGroupIDs)
    }
}

public typealias Catalog = Configuration

extension Configuration {
    var sortedProductIDs: [Product.ID] {
        self.productIDs.sorted()
    }

    var sortedSubscriptionGroupIDs: [String] {
        self.subscriptionGroupIDs.sorted()
    }
}
