import StoreKit
import SubKit
import SwiftUI

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
private enum ProductLoadState<Value> {
    case loading
    case loaded(Value)
    case empty
    case failed(String)
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
public struct SubKitProductView: View {
    private let productID: Product.ID
    private let prefersPromotionalIcon: Bool
    private let icon: (() -> AnyView)?
    private let placeholderIcon: (() -> AnyView)?

    @State private var loadState = ProductLoadState<Product>.loading

    public init(id productID: Product.ID, prefersPromotionalIcon: Bool = false) {
        self.productID = productID
        self.prefersPromotionalIcon = prefersPromotionalIcon
        self.icon = nil
        self.placeholderIcon = nil
    }

    public init<Icon: View>(
        id productID: Product.ID,
        prefersPromotionalIcon: Bool = false,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.productID = productID
        self.prefersPromotionalIcon = prefersPromotionalIcon
        self.icon = { AnyView(icon()) }
        self.placeholderIcon = nil
    }

    public init<Icon: View, Placeholder: View>(
        id productID: Product.ID,
        prefersPromotionalIcon: Bool = false,
        @ViewBuilder icon: @escaping () -> Icon,
        @ViewBuilder placeholderIcon: @escaping () -> Placeholder
    ) {
        self.productID = productID
        self.prefersPromotionalIcon = prefersPromotionalIcon
        self.icon = { AnyView(icon()) }
        self.placeholderIcon = { AnyView(placeholderIcon()) }
    }

    public var body: some View {
        Group {
            switch self.loadState {
            case .loading:
                ProgressView()
            case let .loaded(product):
                self.productView(product)
            case .empty:
                ContentUnavailableView(
                    "Product Unavailable",
                    systemImage: "shippingbox",
                    description: Text("This product is unavailable in the current storefront.")
                )
            case let .failed(message):
                ContentUnavailableView(
                    "Product Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .task(id: self.productID) {
            await self.loadTask()
        }
    }

    @ViewBuilder
    private func productView(_ product: Product) -> some View {
        if let icon = self.icon, let placeholderIcon = self.placeholderIcon {
            ProductView(
                id: product.id,
                prefersPromotionalIcon: self.prefersPromotionalIcon,
                icon: { icon() },
                placeholderIcon: { placeholderIcon() }
            )
        } else if let icon = self.icon {
            ProductView(
                product,
                prefersPromotionalIcon: self.prefersPromotionalIcon,
                icon: { icon() }
            )
        } else {
            ProductView(product, prefersPromotionalIcon: self.prefersPromotionalIcon)
        }
    }

    private func loadTask() async {
        self.loadState = .loading

        do {
            let products = try await Product.products(for: [self.productID])
            guard let product = products.first else {
                self.loadState = .empty
                return
            }
            self.loadState = .loaded(product)
        } catch {
            self.loadState = .failed(self.errorDescription(error))
        }
    }

    private func errorDescription(_ error: some Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return String(describing: error)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
public struct SubKitStoreView: View {
    private let productIDs: [Product.ID]
    private let prefersPromotionalIcon: Bool
    private let icon: ((Product) -> AnyView)?

    @State private var loadState = ProductLoadState<[Product]>.loading

    public init(ids productIDs: some Collection<Product.ID>, prefersPromotionalIcon: Bool = false) {
        self.productIDs = Array(productIDs)
        self.prefersPromotionalIcon = prefersPromotionalIcon
        self.icon = nil
    }

    public init<Icon: View>(
        ids productIDs: some Collection<Product.ID>,
        prefersPromotionalIcon: Bool = false,
        @ViewBuilder icon: @escaping (Product) -> Icon
    ) {
        self.productIDs = Array(productIDs)
        self.prefersPromotionalIcon = prefersPromotionalIcon
        self.icon = { AnyView(icon($0)) }
    }

    public var body: some View {
        Group {
            switch self.loadState {
            case .loading:
                ProgressView()
            case let .loaded(products):
                self.storeView(products)
            case .empty:
                ContentUnavailableView(
                    "Store Unavailable",
                    systemImage: "basket",
                    description: Text("No products are available in the current storefront.")
                )
            case let .failed(message):
                ContentUnavailableView(
                    "Store Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .task(id: self.productIDs) {
            await self.loadTask()
        }
    }

    @ViewBuilder
    private func storeView(_ products: [Product]) -> some View {
        if let icon = self.icon {
            StoreView(
                products: products,
                prefersPromotionalIcon: self.prefersPromotionalIcon,
                icon: { product in
                    icon(product)
                }
            )
        } else {
            StoreView(products: products, prefersPromotionalIcon: self.prefersPromotionalIcon)
        }
    }

    private func loadTask() async {
        guard !self.productIDs.isEmpty else {
            self.loadState = .empty
            return
        }

        self.loadState = .loading

        do {
            let products = try await Product.products(for: self.productIDs)
            self.loadState = products.isEmpty ? .empty : .loaded(products.sorted(by: self.sortProducts))
        } catch {
            self.loadState = .failed(self.errorDescription(error))
        }
    }

    private func sortProducts(_ lhs: Product, _ rhs: Product) -> Bool {
        if lhs.price == rhs.price {
            return lhs.id < rhs.id
        }
        return lhs.price < rhs.price
    }

    private func errorDescription(_ error: some Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return String(describing: error)
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
public struct SubKitSubscriptionStoreView: View {
    private enum Source {
        case groupID(String)
        case productIDs([Product.ID])
    }

    private let source: Source
    private let visibleRelationships: Product.SubscriptionRelationship
    private let marketingContent: (() -> AnyView)?

    @State private var loadState = ProductLoadState<[Product]>.loading

    public init(
        groupID: String,
        visibleRelationships: Product.SubscriptionRelationship = .all
    ) {
        self.source = .groupID(groupID)
        self.visibleRelationships = visibleRelationships
        self.marketingContent = nil
    }

    public init<Content: View>(
        groupID: String,
        visibleRelationships: Product.SubscriptionRelationship = .all,
        @ViewBuilder marketingContent: @escaping () -> Content
    ) {
        self.source = .groupID(groupID)
        self.visibleRelationships = visibleRelationships
        self.marketingContent = { AnyView(marketingContent()) }
    }

    public init(productIDs: some Collection<Product.ID>) {
        self.source = .productIDs(Array(productIDs))
        self.visibleRelationships = .all
        self.marketingContent = nil
    }

    public init<Content: View>(
        productIDs: some Collection<Product.ID>,
        @ViewBuilder marketingContent: @escaping () -> Content
    ) {
        self.source = .productIDs(Array(productIDs))
        self.visibleRelationships = .all
        self.marketingContent = { AnyView(marketingContent()) }
    }

    public var body: some View {
        Group {
            switch self.source {
            case .groupID:
                self.groupBackedView
            case .productIDs:
                self.productBackedView
            }
        }
    }

    @ViewBuilder
    private var groupBackedView: some View {
        if case let .groupID(groupID) = self.source {
            if let marketingContent = self.marketingContent {
                SubscriptionStoreView(
                    groupID: groupID,
                    visibleRelationships: self.visibleRelationships
                ) {
                    marketingContent()
                }
            } else {
                SubscriptionStoreView(
                    groupID: groupID,
                    visibleRelationships: self.visibleRelationships
                )
            }
        }
    }

    @ViewBuilder
    private var productBackedView: some View {
        switch self.loadState {
        case .loading:
            ProgressView()
                .task {
                    await self.productTask()
                }
        case let .loaded(products):
            self.subscriptionStoreView(products)
        case .empty:
            ContentUnavailableView(
                "Subscription Unavailable",
                systemImage: "creditcard",
                description: Text("The subscription is unavailable in the current storefront.")
            )
        case let .failed(message):
            ContentUnavailableView(
                "Subscription Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }

    @ViewBuilder
    private func subscriptionStoreView(_ products: [Product]) -> some View {
        if let marketingContent = self.marketingContent {
            SubscriptionStoreView(subscriptions: products) {
                marketingContent()
            }
        } else {
            SubscriptionStoreView(subscriptions: products)
        }
    }

    private func productTask() async {
        guard case let .productIDs(productIDs) = self.source else {
            return
        }
        guard !productIDs.isEmpty else {
            self.loadState = .empty
            return
        }

        self.loadState = .loading

        do {
            let products = try await Product.products(for: productIDs)
                .filter { $0.type == .autoRenewable }
            self.loadState = products.isEmpty ? .empty : .loaded(products.sorted(by: self.sortProducts))
        } catch {
            self.loadState = .failed(self.errorDescription(error))
        }
    }

    private func sortProducts(_ lhs: Product, _ rhs: Product) -> Bool {
        if lhs.price == rhs.price {
            return lhs.id < rhs.id
        }
        return lhs.price < rhs.price
    }

    private func errorDescription(_ error: some Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return String(describing: error)
    }
}

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct SubKitManageSubscriptionsButton<Label: View>: View {
    private let subscriptionGroupID: String?
    private let label: () -> Label

    @State private var isPresented = false

    public init(
        subscriptionGroupID: String? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.subscriptionGroupID = subscriptionGroupID
        self.label = label
    }

    public var body: some View {
        Button {
            self.isPresented = true
        } label: {
            self.label()
        }
        .modifier(ManageSubscriptionsSheetModifier(
            isPresented: self.$isPresented,
            subscriptionGroupID: self.subscriptionGroupID
        ))
    }
}

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension SubKitManageSubscriptionsButton where Label == Text {
    public init(
        _ title: LocalizedStringKey = "Manage Subscription",
        subscriptionGroupID: String? = nil
    ) {
        self.init(subscriptionGroupID: subscriptionGroupID) {
            Text(title)
        }
    }
}

@available(iOS 15.0, visionOS 1.0, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
private struct ManageSubscriptionsSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let subscriptionGroupID: String?

    func body(content: Content) -> some View {
        if let subscriptionGroupID {
            if #available(iOS 17.0, *) {
                content.manageSubscriptionsSheet(
                    isPresented: self.$isPresented,
                    subscriptionGroupID: subscriptionGroupID
                )
            } else {
                content.manageSubscriptionsSheet(isPresented: self.$isPresented)
            }
        } else {
            content.manageSubscriptionsSheet(isPresented: self.$isPresented)
        }
    }
}

#Preview("SubKit Product") {
    if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
        SubKitProductView(id: "com.example.subkit.lifetime")
            .padding()
    }
}

#Preview("SubKit Store") {
    if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
        NavigationStack {
            SubKitStoreView(
                ids: [
                    "com.example.subkit.lifetime",
                    "com.example.subkit.monthly",
                    "com.example.subkit.yearly",
                ]
            )
            .navigationTitle("SubKit")
        }
    }
}

#Preview("SubKit Subscription") {
    if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
        SubKitSubscriptionStoreView(
            productIDs: [
                "com.example.subkit.monthly",
                "com.example.subkit.yearly",
            ]
        )
    }
}
