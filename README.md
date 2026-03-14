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

## Notes

- v1 supports auto-renewable subscriptions and non-consumables.
- Consumables are currently out of scope.
- The package does not perform backend networking for you.
- Send StoreKit transaction data or JWS to your backend after a successful purchase.
- The `productIDs`-backed UI wrappers can show `ContentUnavailableView` for empty and error states.
- The `groupID`-only subscription view still relies on Apple’s `SubscriptionStoreView(groupID:)`, because StoreKit does not provide a direct way to enumerate every product in a subscription group from the group ID alone.

## Previews

`SubKitUI` includes `#Preview` blocks in [Sources/SubKitUI/SubKitViews.swift](./Sources/SubKitUI/SubKitViews.swift) for:

- product view
- store view
- subscription view
