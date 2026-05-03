//
//  SubscriptionManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import Foundation
import StoreKit

enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.versegates.cliparc.pro.monthly"
    case yearly = "com.versegates.cliparc.pro.yearly"
    case lifetime = "com.versegates.cliparc.lifetime"

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    var description: String {
        switch self {
        case .monthly: return "$2.99/month"
        case .yearly: return "$19.99/year (Save 44%)"
        case .lifetime: return "$59.99 one-time"
        }
    }

    var isSubscription: Bool {
        switch self {
        case .monthly, .yearly: return true
        case .lifetime: return false
        }
    }
}

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    /// Set to `true` to enable subscription paywall. When `false`, all features are free.
    static let subscriptionsEnabled = false

    var products: [Product] = []
    var purchasedSubscriptions: [Product] = []
    var isSubscribed = false
    var hasLifetimePurchase = false
    var isLoading = false
    var hasFailedLoading = false
    var errorMessage: String?
    var subscriptionExpirationDate: Date?

    private var updateListenerTask: Task<Void, Error>?
    private static let maxRetryAttempts = 3

    private init() {
        guard Self.subscriptionsEnabled else { return }
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }

    func cleanup() {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        hasFailedLoading = false
        errorMessage = nil

        let productIDs = SubscriptionProduct.allCases.map { $0.rawValue }
        print("[SubscriptionManager] Requesting products: \(productIDs)")
        print("[SubscriptionManager] Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")

        for attempt in 1...Self.maxRetryAttempts {
            do {
                print("[SubscriptionManager] Attempt \(attempt)/\(Self.maxRetryAttempts)...")
                let fetchedProducts = try await Product.products(for: productIDs)
                print("[SubscriptionManager] Fetched \(fetchedProducts.count) products: \(fetchedProducts.map { "\($0.id) - \($0.displayPrice)" })")

                if fetchedProducts.isEmpty {
                    // StoreKit returned success but no products — treat as failure
                    print("[SubscriptionManager] WARNING: StoreKit returned empty products array")
                    if attempt < Self.maxRetryAttempts {
                        try? await Task.sleep(for: .seconds(attempt))
                        continue
                    } else {
                        errorMessage = String(localized: "subscription.products_unavailable")
                        isLoading = false
                        hasFailedLoading = true
                        return
                    }
                }

                products = fetchedProducts.sorted { $0.price < $1.price }
                isLoading = false
                hasFailedLoading = false
                return
            } catch {
                print("[SubscriptionManager] Error on attempt \(attempt): \(error)")
                if attempt < Self.maxRetryAttempts {
                    // Wait before retrying: 1s, 2s
                    try? await Task.sleep(for: .seconds(attempt))
                } else {
                    errorMessage = String(localized: "subscription.load_failed \(error.localizedDescription)")
                    isLoading = false
                    hasFailedLoading = true
                }
            }
        }
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateSubscriptionStatus()
                await transaction.finish()
                isLoading = false
                return true

            case .userCancelled:
                isLoading = false
                return false

            case .pending:
                errorMessage = "Purchase is pending approval."
                isLoading = false
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            isLoading = false

            if !isSubscribed {
                errorMessage = "No active subscription found."
            }
        } catch is CancellationError {
            // User cancelled - silently ignore
            isLoading = false
        } catch StoreKitError.userCancelled {
            // User cancelled - silently ignore
            isLoading = false
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var hasLifetime = false
        var latestExpirationDate: Date?

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    hasActiveSubscription = true
                    if let expirationDate = transaction.expirationDate {
                        if latestExpirationDate == nil || expirationDate > latestExpirationDate! {
                            latestExpirationDate = expirationDate
                        }
                    }
                } else if transaction.productType == .nonConsumable {
                    // Lifetime purchase
                    if transaction.productID == SubscriptionProduct.lifetime.rawValue {
                        hasLifetime = true
                    }
                }
            }
        }

        hasLifetimePurchase = hasLifetime
        isSubscribed = hasActiveSubscription || hasLifetime
        subscriptionExpirationDate = hasLifetime ? nil : latestExpirationDate
    }

    var isPro: Bool {
        if !Self.subscriptionsEnabled { return true }
        return isSubscribed || hasLifetimePurchase
    }

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    func getProduct(for subscriptionType: SubscriptionProduct) -> Product? {
        return products.first { $0.id == subscriptionType.rawValue }
    }

    var monthlyProduct: Product? {
        getProduct(for: .monthly)
    }

    var yearlyProduct: Product? {
        getProduct(for: .yearly)
    }

    var lifetimeProduct: Product? {
        getProduct(for: .lifetime)
    }

    var subscriptionProducts: [Product] {
        products.filter { product in
            product.id != SubscriptionProduct.lifetime.rawValue
        }
    }
}

enum SubscriptionError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed."
        }
    }
}
