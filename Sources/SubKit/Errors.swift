import Foundation
import StoreKit

public enum SubKitError: Error, CustomStringConvertible {
    case productNotFound(Product.ID)
    case unsupportedProductType(productID: Product.ID, type: Product.ProductType)
    case failedVerification(productID: Product.ID, jwsRepresentation: String, reason: String)

    public var description: String {
        switch self {
        case let .productNotFound(productID):
            return "No StoreKit product could be loaded for '\(productID)'."
        case let .unsupportedProductType(productID, type):
            return "Product '\(productID)' uses unsupported type '\(type)'."
        case let .failedVerification(productID, _, reason):
            return "StoreKit verification failed for '\(productID)': \(reason)."
        }
    }
}
