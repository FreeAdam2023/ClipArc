//
//  AuthManagerTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-21.
//

import XCTest
@testable import ClipArc

@MainActor
final class AuthManagerTests: XCTestCase {

    // Note: AuthManager uses a shared singleton, so we test its behavior
    // rather than creating instances. For proper unit testing, the singleton
    // pattern should be refactored to allow dependency injection.

    // MARK: - Sign Out Tests

    func testSignOutClearsCredentials() {
        let authManager = AuthManager.shared

        // First sign out to ensure clean state
        authManager.signOut()

        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.userID)
        XCTAssertNil(authManager.userEmail)
        XCTAssertNil(authManager.userName)
    }

    func testSignOutClearsUserDefaults() {
        let authManager = AuthManager.shared

        // Set some test values
        UserDefaults.standard.set("testUserID", forKey: "appleUserID")
        UserDefaults.standard.set("test@example.com", forKey: "appleUserEmail")
        UserDefaults.standard.set("Test User", forKey: "appleUserName")

        authManager.signOut()

        XCTAssertNil(UserDefaults.standard.string(forKey: "appleUserID"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "appleUserEmail"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "appleUserName"))
    }

    // MARK: - Initial State Tests

    func testInitialStateAfterSignOut() {
        let authManager = AuthManager.shared
        authManager.signOut()

        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertFalse(authManager.isLoading)
        XCTAssertNil(authManager.errorMessage)
    }

    // MARK: - Error Message Tests

    func testErrorMessageCanBeSet() {
        let authManager = AuthManager.shared
        authManager.signOut()

        authManager.errorMessage = "Test error"
        XCTAssertEqual(authManager.errorMessage, "Test error")

        authManager.errorMessage = nil
        XCTAssertNil(authManager.errorMessage)
    }
}
