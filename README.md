# SubKit

Minimal StoreKit 2 helpers for subscriptions and one-off in-app purchases.

`SubKit` is split into two library products:

- `SubKit`: product loading, purchasing, entitlements, subscription status, and manual sync.
- `SubKitUI`: SwiftUI-first StoreKit merchandising wrappers plus UIKit hosting helpers.

## Platforms

- iOS 15+
- macOS 12+
- tvOS 15+
- watchOS 8+
- visionOS 1+

`SubKitUI` uses StoreKit SwiftUI APIs, so its UI views are available on:

- iOS 17+
- macOS 14+
- tvOS 17+
- watchOS 10+
- visionOS 1+

## Installation

Add the package to your app and import the product you need:

```swift
import SubKit
import SubKitUI
```

## Core Usage

Create a catalog in code. StoreKit does not expose a general API to fetch all of your App Store Connect product IDs automatically, so you provide them yourself.

```swift
import SubKit

let subKit = SubKitClient(
  configuration: Configuration(
    productIDs: [
      "com.example.subkit.lifetime",
      "com.example.subkit.monthly",
      "com.example.subkit.yearly",
    ],
    subscriptionGroupIDs: [
      "5982C3D1"
    ]
  )
)
```

Load products as early as you want in app startup or when entering your paywall:

```swift
let products = try await subKit.loadProducts()
```

### Purchase a Product

```swift
let result = try await subKit.purchase(
  productID: "com.example.subkit.monthly",
  appAccountToken: UUID()
)

switch result {
case let .success(purchase):
  // Send purchase.jwsRepresentation or purchase.transaction
  // to your backend for server-side verification / entitlement sync.
  print(purchase.productID)

case .pending:
  // Ask to Buy / SCA / approval flow is still pending.
  break

case .userCancelled:
  break
}
```

### UIKit Purchase Confirmation

For UIKit apps, you can confirm purchases in a view controller or scene:

```swift
let result = try await subKit.purchase(
  productID: "com.example.subkit.lifetime",
  appAccountToken: UUID(),
  confirmingIn: viewController
)
```

```swift
let result = try await subKit.purchase(
  productID: "com.example.subkit.lifetime",
  appAccountToken: UUID(),
  confirmingIn: scene
)
```

### Entitlements

Read the current non-consumable and subscription entitlements:

```swift
let entitlements = try await subKit.currentEntitlements()
```

Each `Entitlement` includes:

- `productID`
- `kind`
- `transactionID`
- `originalTransactionID`
- `purchaseDate`
- `expirationDate`
- `revocationDate`
- `appAccountToken`
- `transaction`
- `jwsRepresentation`

### Subscription Status

```swift
let statuses = try await subKit.subscriptionStatuses(groupID: "5982C3D1")
```

### Manual Sync

StoreKit 2 keeps purchases synchronized automatically in normal cases. For the rare “restore purchases” equivalent, expose a user-driven action:

```swift
let refreshedEntitlements = try await subKit.syncPurchases()
```

## SwiftUI UI Usage

`SubKitUI` wraps Apple’s StoreKit SwiftUI views and adds better empty/error handling for product-backed views using `ContentUnavailableView`.

### Single Product

```swift
import SubKitUI

SubKitProductView(id: "com.example.subkit.lifetime")
```

### Store View

```swift
SubKitStoreView(
  ids: [
    "com.example.subkit.lifetime",
    "com.example.subkit.monthly",
    "com.example.subkit.yearly",
  ]
)
```

### Subscription Store

Preferred when you know the products:

```swift
SubKitSubscriptionStoreView(
  productIDs: [
    "com.example.subkit.monthly",
    "com.example.subkit.yearly",
  ]
)
```

You can also use a subscription group ID:

```swift
SubKitSubscriptionStoreView(groupID: "5982C3D1")
```

You can also scope the store to relationship-specific flows, such as upgrades:

```swift
SubKitSubscriptionStoreView(
  groupID: "5982C3D1",
  visibleRelationships: .upgrade
)
```

### StoreKit Modifiers

Because the wrappers are ordinary SwiftUI views around Apple's StoreKit views, you can chain StoreKit SwiftUI modifiers directly on them.

Subscription examples:

```swift
SubKitSubscriptionStoreView(groupID: "5982C3D1") {
  PassMarketingContent()
}
.storeButton(.visible, for: .redeemCode, .policies)
.subscriptionStorePolicyForegroundStyle(.white)
.subscriptionStoreButtonLabel(.multiline.displayName)
.subscriptionStoreControlStyle(.buttons)
```

You can also react to StoreKit-driven purchases from descendant merchandising views:

```swift
SubKitStoreView(ids: ["com.example.subkit.lifetime"])
  .onInAppPurchaseStart { product in
    print("Starting purchase for \\(product.id)")
  }
  .onInAppPurchaseCompletion { product, result in
    print("Completed purchase for \\(product.id): \\(result)")
  }
```

Common modifiers and tasks you can use directly on `SubKitUI` views include:

- `.storeButton(..., for: .redeemCode, .policies, .restorePurchases, .signIn)`
- `.subscriptionStoreSignInAction { ... }`
- `.subscriptionStorePolicyForegroundStyle(...)`
- `.subscriptionStoreButtonLabel(...)`
- `.subscriptionStoreControlStyle(...)`
- `.subscriptionStoreControlIcon { ... }`
- `.backgroundStyle(...)`
- `.productViewStyle(...)`
- `.onInAppPurchaseStart { ... }`
- `.onInAppPurchaseCompletion { ... }`
- `.subscriptionStatusTask(for:)`
- `.currentEntitlementTask(for:)`
- `.storeProductsTask(for:)`

### Manage Or Cancel A Subscription

StoreKit can present Apple’s built-in subscription-management sheet from inside your app.

If you want the call site to control presentation, create a model and toggle it:

```swift
@State var manageSubscriptions = SubKitManageSubscriptionsModel(
  subscriptionGroupID: "5982C3D1"
)
```

Mount the presenter somewhere in the view tree:

```swift
SubKitManageSubscriptionsPresenter(model: manageSubscriptions)
```

Then trigger it from any UI:

```swift
Button("Manage Subscription") {
  manageSubscriptions.present()
}
```

Or use the built-in button wrapper:

```swift
SubKitManageSubscriptionsButton()
```

If you want to scope the sheet to a specific subscription group:

```swift
SubKitManageSubscriptionsButton(
  subscriptionGroupID: "5982C3D1"
)
```

You can also give the button an external model:

```swift
SubKitManageSubscriptionsButton(model: manageSubscriptions) {
  Label("Manage Subscription", systemImage: "gear")
}
```

You can also provide a custom label:

```swift
SubKitManageSubscriptionsButton(subscriptionGroupID: "5982C3D1") {
  Label("Manage Subscription", systemImage: "gear")
}
```

## UIKit UI Usage

Host the SwiftUI wrappers in UIKit:

```swift
let controller = SubKitProductViewController(
  productID: "com.example.subkit.lifetime"
)
```

```swift
let controller = SubKitStoreViewController(
  productIDs: [
    "com.example.subkit.lifetime",
    "com.example.subkit.monthly",
  ]
)
```

```swift
let controller = SubKitSubscriptionStoreViewController(
  productIDs: [
    "com.example.subkit.monthly",
    "com.example.subkit.yearly",
  ]
)
```

If you need StoreKit SwiftUI modifiers in UIKit, host the SwiftUI view directly instead of using the convenience controller:

```swift
let view = SubKitSubscriptionStoreView(groupID: "5982C3D1")
  .storeButton(.visible, for: .redeemCode, .policies)
  .subscriptionStorePolicyForegroundStyle(.white)

let controller = UIHostingController(rootView: view)
```

### UIKit Manage Subscriptions

For UIKit, the more reliable approach is to host the SwiftUI button directly and add it as a child view controller:

```swift
final class SettingsViewController: UIViewController {
  private lazy var manageSubscriptionsButtonController = UIHostingController(
    rootView: SubKitManageSubscriptionsButton(
      subscriptionGroupID: "5982C3D1"
    ) {
      Label("Manage Subscription", systemImage: "gear")
    }
  )

  override func viewDidLoad() {
    super.viewDidLoad()

    addChild(manageSubscriptionsButtonController)
    view.addSubview(manageSubscriptionsButtonController.view)
    manageSubscriptionsButtonController.view.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      manageSubscriptionsButtonController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      manageSubscriptionsButtonController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
    ])

    manageSubscriptionsButtonController.didMove(toParent: self)
  }
}
```

That keeps the actual StoreKit SwiftUI button in the view hierarchy, which has been much more reliable than trying to bridge `manageSubscriptionsSheet` through an invisible UIKit presenter.

## Notes

- v1 supports auto-renewable subscriptions and non-consumables.
- Consumables are currently out of scope.
- The package does not perform backend networking for you.
- Send StoreKit transaction data or JWS to your backend after a successful purchase.
- The `productIDs`-backed UI wrappers can show `ContentUnavailableView` for empty and error states.
- The `groupID`-only subscription view still relies on Apple’s `SubscriptionStoreView(groupID:)`, because StoreKit does not provide a direct way to enumerate every product in a subscription group from the group ID alone.
- `visibleRelationships` is supported on the `groupID` subscription initializer, so upgrade, downgrade, crossgrade, and current-plan focused views are available there.
- `SubKitSubscriptionStoreView` does not currently expose control over the initially selected subscription plan. On the current public StoreKit API, Apple chooses the default selection.
- Many advanced StoreKit SwiftUI capabilities are available by chaining modifiers directly on the wrappers rather than through dedicated `SubKit` APIs.
- The UIKit convenience controllers are intentionally thin and do not expose configuration points for SwiftUI StoreKit modifiers. Use `UIHostingController` directly when you need modifier-based customization.
- `SubKitManageSubscriptionsButton` and `SubKitManageSubscriptionsPresenter` present Apple’s subscription-management UI, which lets customers manage or cancel App Store subscriptions from inside your app.
- In SwiftUI, manage-subscriptions state is owned with `@State` and driven by `SubKitManageSubscriptionsModel`.
- For UIKit, hosting `SubKitManageSubscriptionsButton` in a `UIHostingController` is the recommended subscription-management integration.
- `SubKitUI` focuses on turnkey wrappers around Apple's built-in merchandising views. It does not yet provide a higher-level API for fully custom StoreKit SwiftUI paywalls built around `storeProductsTask`, `Product.CollectionTaskState`, or custom subscription pickers.

## Previews

`SubKitUI` includes `#Preview` blocks in [Sources/SubKitUI/SubKitViews.swift](./Sources/SubKitUI/SubKitViews.swift) for:

- product view
- store view
- subscription view
