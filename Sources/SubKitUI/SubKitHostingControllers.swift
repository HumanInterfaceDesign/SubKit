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

@available(iOS 15.0, visionOS 1.0, *)
@available(tvOS, unavailable)
public final class SubKitManageSubscriptionsViewController: UIHostingController<SubKitManageSubscriptionsPresenter> {
    public let model: SubKitManageSubscriptionsModel

    public init(model: SubKitManageSubscriptionsModel) {
        self.model = model
        super.init(rootView: SubKitManageSubscriptionsPresenter(model: model))
    }

    public init(subscriptionGroupID: String? = nil) {
        let model = SubKitManageSubscriptionsModel(subscriptionGroupID: subscriptionGroupID)
        self.model = model
        super.init(rootView: SubKitManageSubscriptionsPresenter(model: model))
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        nil
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        self.view.isOpaque = false
        self.view.isUserInteractionEnabled = false
    }

    public func attach(to parent: UIViewController) {
        guard self.parent !== parent else { return }

        self.willMove(toParent: nil)
        self.view.removeFromSuperview()
        self.removeFromParent()

        parent.addChild(self)
        self.view.translatesAutoresizingMaskIntoConstraints = false
        parent.view.addSubview(self.view)
        NSLayoutConstraint.activate([
            self.view.topAnchor.constraint(equalTo: parent.view.topAnchor),
            self.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
            self.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
            self.view.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor),
        ])
        self.didMove(toParent: parent)
    }
}

#endif
