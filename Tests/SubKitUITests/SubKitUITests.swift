import SwiftUI
import Testing
import SubKitUI

@Suite
@MainActor
struct SubKitUITests {
    @Test
    func swiftUIWrappersInstantiate() {
        guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) else {
            return
        }

        let productView = SubKitProductView(id: "com.example.subkit.lifetime")
        let storeView = SubKitStoreView(ids: ["com.example.subkit.lifetime", "com.example.subkit.monthly"])
        let subscriptionView = SubKitSubscriptionStoreView(groupID: "5982C3D1")

        _ = productView.body
        _ = storeView.body
        _ = subscriptionView.body

        #if os(iOS) || os(visionOS)
        if #available(iOS 15.0, visionOS 1.0, *) {
            let manageSubscriptionsButton = SubKitManageSubscriptionsButton(
                model: SubKitManageSubscriptionsModel(subscriptionGroupID: "5982C3D1")
            ) {
                Text("Manage Subscription")
            }
            let manageSubscriptionsPresenter = SubKitManageSubscriptionsPresenter(
                model: SubKitManageSubscriptionsModel(subscriptionGroupID: "5982C3D1")
            )

            _ = manageSubscriptionsButton.body
            _ = manageSubscriptionsPresenter.body
        }
        #endif
    }
}
