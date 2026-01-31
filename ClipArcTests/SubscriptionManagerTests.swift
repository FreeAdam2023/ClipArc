//
//  SubscriptionManagerTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-21.
//

import XCTest
@testable import ClipArc

final class SubscriptionProductTests: XCTestCase {

    // MARK: - Raw Value Tests

    func testMonthlyRawValue() {
        XCTAssertEqual(SubscriptionProduct.monthly.rawValue, "com.versegates.cliparc.pro.monthly")
    }

    func testYearlyRawValue() {
        XCTAssertEqual(SubscriptionProduct.yearly.rawValue, "com.versegates.cliparc.pro.yearly")
    }

    func testLifetimeRawValue() {
        XCTAssertEqual(SubscriptionProduct.lifetime.rawValue, "com.versegates.cliparc.lifetime")
    }

    // MARK: - Display Name Tests

    func testDisplayNames() {
        XCTAssertEqual(SubscriptionProduct.monthly.displayName, "Monthly")
        XCTAssertEqual(SubscriptionProduct.yearly.displayName, "Yearly")
        XCTAssertEqual(SubscriptionProduct.lifetime.displayName, "Lifetime")
    }

    // MARK: - Description Tests

    func testDescriptions() {
        XCTAssertEqual(SubscriptionProduct.monthly.description, "$2.99/month")
        XCTAssertEqual(SubscriptionProduct.yearly.description, "$19.99/year (Save 44%)")
        XCTAssertEqual(SubscriptionProduct.lifetime.description, "$59.99 one-time")
    }

    // MARK: - Is Subscription Tests

    func testIsSubscription() {
        XCTAssertTrue(SubscriptionProduct.monthly.isSubscription)
        XCTAssertTrue(SubscriptionProduct.yearly.isSubscription)
        XCTAssertFalse(SubscriptionProduct.lifetime.isSubscription)
    }

    // MARK: - All Cases Tests

    func testAllCases() {
        let allCases = SubscriptionProduct.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.monthly))
        XCTAssertTrue(allCases.contains(.yearly))
        XCTAssertTrue(allCases.contains(.lifetime))
    }
}

final class SubscriptionErrorTests: XCTestCase {

    func testFailedVerificationErrorDescription() {
        let error = SubscriptionError.failedVerification
        XCTAssertEqual(error.errorDescription, "Transaction verification failed.")
    }
}

@MainActor
final class SubscriptionManagerTests: XCTestCase {

    // Note: SubscriptionManager uses a shared singleton and StoreKit,
    // making it difficult to unit test without dependency injection.
    // These tests verify basic state behavior.

    func testManagerExists() {
        let manager = SubscriptionManager.shared
        XCTAssertNotNil(manager)
    }

    func testProductsArrayExists() {
        let manager = SubscriptionManager.shared
        // Products array exists (may be empty if StoreKit not configured)
        XCTAssertNotNil(manager.products)
    }

    func testIsProReflectsSubscriptionState() {
        let manager = SubscriptionManager.shared

        // isPro should match isSubscribed || hasLifetimePurchase
        let expectedPro = manager.isSubscribed || manager.hasLifetimePurchase
        XCTAssertEqual(manager.isPro, expectedPro)
    }
}
