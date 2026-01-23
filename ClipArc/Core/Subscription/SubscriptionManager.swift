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

    var products: [Product] = []
    var purchasedSubscriptions: [Product] = []
    var isSubscribed = false
    var hasLifetimePurchase = false
    var isLoading = false
    var errorMessage: String?
    var subscriptionExpirationDate: Date?

    private var updateListenerTask: Task<Void, Error>?

    private init() {
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
        do {
            let productIDs = SubscriptionProduct.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
            products.sort { $0.price < $1.price }
            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
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
        isSubscribed || hasLifetimePurchase
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
