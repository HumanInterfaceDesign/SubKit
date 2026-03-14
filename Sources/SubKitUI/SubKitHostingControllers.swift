import SwiftUI

#if canImport(UIKit)
import UIKit

@available(iOS 17.0, tvOS 17.0, visionOS 1.0, *)
public final class SubKitProductViewController: UIHostingController<SubKitProductView> {
    public init(productID: String, prefersPromotionalIcon: Bool = false) {
        super.init(rootView: SubKitProductView(id: productID, prefersPromotionalIcon: prefersPromotionalIcon))
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }
}

@available(iOS 17.0, tvOS 17.0, visionOS 1.0, *)
public final class SubKitStoreViewController: UIHostingController<SubKitStoreView> {
    public init(productIDs: [String], prefersPromotionalIcon: Bool = false) {
        super.init(rootView: SubKitStoreView(ids: productIDs, prefersPromotionalIcon: prefersPromotionalIcon))
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }
}

@available(iOS 17.0, tvOS 17.0, visionOS 1.0, *)
public final class SubKitSubscriptionStoreViewController: UIHostingController<SubKitSubscriptionStoreView> {
    public init(groupID: String) {
        super.init(rootView: SubKitSubscriptionStoreView(groupID: groupID))
    }

    public init(productIDs: [String]) {
        super.init(rootView: SubKitSubscriptionStoreView(productIDs: productIDs))
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }
}
#endif
