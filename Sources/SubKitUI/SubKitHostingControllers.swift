import SwiftUI

#if canImport(UIKit)
import UIKit

@available(iOS 17.0, tvOS 17.0, visionOS 1.0, *)
public final class SubKitProductViewController: UIHostingController<SubKitProductView> {
    public init(
        productID: String,
        appAccountToken: UUID? = nil,
        prefersPromotionalIcon: Bool = false
    ) {
        super.init(
            rootView: SubKitProductView(
                id: productID,
                appAccountToken: appAccountToken,
                prefersPromotionalIcon: prefersPromotionalIcon
            )
        )
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }
}

@available(iOS 17.0, tvOS 17.0, visionOS 1.0, *)
public final class SubKitStoreViewController: UIHostingController<SubKitStoreView> {
    public init(
        productIDs: [String],
        appAccountToken: UUID? = nil,
        prefersPromotionalIcon: Bool = false
    ) {
        super.init(
            rootView: SubKitStoreView(
                ids: productIDs,
                appAccountToken: appAccountToken,
                prefersPromotionalIcon: prefersPromotionalIcon
            )
        )
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }
}

@available(iOS 17.0, tvOS 17.0, visionOS 1.0, *)
public final class SubKitSubscriptionStoreViewController: UIHostingController<SubKitSubscriptionStoreView> {
    public init(groupID: String, appAccountToken: UUID? = nil) {
        super.init(
            rootView: SubKitSubscriptionStoreView(
                groupID: groupID,
                appAccountToken: appAccountToken
            )
        )
    }

    public init(productIDs: [String], appAccountToken: UUID? = nil) {
        super.init(
            rootView: SubKitSubscriptionStoreView(
                productIDs: productIDs,
                appAccountToken: appAccountToken
            )
        )
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }
}

#endif
