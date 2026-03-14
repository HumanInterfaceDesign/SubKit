import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import SubKit

@Suite(.serialized)
struct BaseStoreKitSuite {}

extension BaseStoreKitSuite {
    @Suite
    struct CoreTests {
        @Test
        func loadProducts() async throws {
            guard try await self.hasStoreKitTestEnvironment() else { return }
            let session = try self.makeSession()
            let client = self.makeClient()

            let products = try await client.loadProducts()

            #expect(products.map(\.id) == [
                TestCatalog.monthly,
                TestCatalog.lifetime,
                TestCatalog.yearly,
            ])
            #expect(products.map(\.type) == [
                .autoRenewable,
                .nonConsumable,
                .autoRenewable,
            ])
            _ = session
        }

        @Test
        func loadProductsNetworkFailure() async throws {
            guard try await self.hasStoreKitTestEnvironment() else { return }
            let session = try self.makeSession()
            try await session.setSimulatedError(
                .generic(.networkError(URLError(.notConnectedToInternet))),
                forAPI: .loadProducts
            )

            let client = self.makeClient()

            do {
                _ = try await client.loadProducts()
                Issue.record("Expected product loading to throw a network error.")
            } catch StoreKitError.networkError {
            }
        }

        @Test
        func oneOffPurchaseSuccessRefreshesEntitlements() async throws {
            guard try await self.hasStoreKitTestEnvironment() else { return }
            let _ = try self.makeSession()
            let client = self.makeClient()

            _ = try await client.loadProducts()
            let result = try await client.purchase(
                productID: TestCatalog.lifetime,
                appAccountToken: TestCatalog.accountToken
            )

            switch result {
            case let .success(purchase):
                #expect(purchase.productID == TestCatalog.lifetime)
                #expect(purchase.appAccountToken == TestCatalog.accountToken)
                #expect(!purchase.jwsRepresentation.isEmpty)
            default:
                Issue.record("Expected purchase success, got \(String(describing: result)).")
            }

            let entitlements = try await client.currentEntitlements()
            #expect(entitlements.count == 1)
            #expect(entitlements.first?.productID == TestCatalog.lifetime)
            #expect(entitlements.first?.kind == .oneOffPurchase)
        }

        @Test
        func purchaseCancellationMapsToResult() async throws {
            guard try await self.hasStoreKitTestEnvironment() else { return }
            let session = try self.makeSession()
            try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)

            let client = self.makeClient()
            _ = try await client.loadProducts()

            let result = try await client.purchase(productID: TestCatalog.lifetime)

            switch result {
            case let .userCancelled(productID, source):
                #expect(productID == TestCatalog.lifetime)
                #expect(source == .inApp)
            default:
                Issue.record("Expected user-cancelled purchase result.")
            }
        }

        @Test
        func pendingPurchaseResolvesAfterApproval() async throws {
            guard try await self.hasStoreKitTestEnvironment() else { return }
            let session = try self.makeSession()
            session.askToBuyEnabled = true

            let client = self.makeClient()
            _ = try await client.loadProducts()

            let result = try await client.purchase(productID: TestCatalog.lifetime)

            switch result {
            case let .pending(productID, source):
                #expect(productID == TestCatalog.lifetime)
                #expect(source == .inApp)
            default:
                Issue.record("Expected pending purchase result.")
            }

            let identifier = try #require(session.allTransactions().first?.identifier)
            try session.approveAskToBuyTransaction(identifier: identifier)

            try await self.waitUntil("approved entitlement shows up") {
                let entitlements = try await client.currentEntitlements()
                return entitlements.contains { $0.productID == TestCatalog.lifetime }
            }
        }

        @Test
        func unverifiedPurchaseThrowsVerificationError() async throws {
            guard try await self.hasStoreKitTestEnvironment() else { return }
            let session = try self.makeSession()
            try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)

            let client = self.makeClient()
            _ = try await client.loadProducts()

            do {
                _ = try await client.purchase(productID: TestCatalog.lifetime)
                Issue.record("Expected purchase verification to fail.")
            } catch let error as SubKitError {
                switch error {
                case let .failedVerification(productID, _, reason):
                    #expect(productID == TestCatalog.lifetime)
                    #expect(reason.contains("invalidSignature"))
                default:
                    Issue.record("Unexpected SubKitError: \(error)")
                }
            }
        }

        @Test
        func subscriptionPurchaseTracksRenewalAndStatus() async throws {
            guard try await self.hasStoreKitTestEnvironment() else { return }
            let session = try self.makeSession()
            session.timeRate = .oneRenewalEveryTwoSeconds

            let client = self.makeClient()
            _ = try await client.loadProducts()

            _ = try await session.buyProduct(identifier: TestCatalog.monthly)

            try await self.waitUntil("subscription entitlement appears") {
                let entitlements = try await client.currentEntitlements()
                return entitlements.contains { $0.productID == TestCatalog.monthly }
            }

            try await self.waitUntil("subscription renews in test session") {
                session.allTransactions().count > 1
            }

            let statuses = try await client.subscriptionStatuses(groupID: TestCatalog.subscriptionGroupID)
            #expect(!statuses.isEmpty)
            #expect(statuses.first?.productID == TestCatalog.monthly)
        }

        @Test
        func transactionListenerSeesOffDevicePurchase() async throws {
            guard try await self.hasStoreKitTestEnvironment() else { return }
            let session = try self.makeSession()
            let client = self.makeClient()

            _ = try await client.loadProducts()
            _ = try await session.buyProduct(identifier: TestCatalog.lifetime)

            try await self.waitUntil("off-device purchase reaches entitlements") {
                let entitlements = try await client.currentEntitlements()
                return entitlements.contains { $0.productID == TestCatalog.lifetime }
            }
        }

        @Test
        func syncPurchasesSmokeTest() async throws {
            guard try await self.hasStoreKitTestEnvironment() else { return }
            let session = try self.makeSession()
            let client = self.makeClient()

            _ = try await client.loadProducts()
            _ = try await session.buyProduct(identifier: TestCatalog.lifetime)

            let entitlements = try await client.syncPurchases()
            #expect(entitlements.contains { $0.productID == TestCatalog.lifetime })
        }
    }
}

private enum TestCatalog {
    static let lifetime = "com.example.subkit.lifetime"
    static let monthly = "com.example.subkit.monthly"
    static let yearly = "com.example.subkit.yearly"
    static let subscriptionGroupID = "5982C3D1"
    static let accountToken = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
}

private extension BaseStoreKitSuite.CoreTests {
    func hasStoreKitTestEnvironment() async throws -> Bool {
        let client = self.makeClient()

        do {
            let products = try await client.loadProducts()
            return products.count == 3
        } catch {
            return false
        }
    }

    func makeClient() -> SubKitClient {
        SubKitClient(
            configuration: Configuration(
                productIDs: [
                    TestCatalog.lifetime,
                    TestCatalog.monthly,
                    TestCatalog.yearly,
                ],
                subscriptionGroupIDs: [TestCatalog.subscriptionGroupID]
            )
        )
    }

    func makeSession() throws -> SKTestSession {
        let url = try #require(Bundle.module.url(forResource: "SubKitTest", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.locale = Locale(identifier: "en_US")
        session.storefront = "USA"
        return session
    }

    func waitUntil(
        _ description: String,
        timeoutNanoseconds: UInt64 = 5_000_000_000,
        pollNanoseconds: UInt64 = 100_000_000,
        predicate: @escaping () async throws -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanoseconds))

        while ContinuousClock.now < deadline {
            if try await predicate() {
                return
            }
            try await Task.sleep(nanoseconds: pollNanoseconds)
        }

        Issue.record("Timed out waiting for \(description).")
    }
}
