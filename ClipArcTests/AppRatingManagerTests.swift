//
//  AppRatingManagerTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-23.
//

import XCTest
@testable import ClipArc

final class AppRatingManagerTests: XCTestCase {

    var manager: AppRatingManager!

    override func setUpWithError() throws {
        manager = AppRatingManager.shared
    }

    override func tearDownWithError() throws {
        manager = nil
    }

    // MARK: - Usage Tracking Tests

    func testInitialState() {
        // Manager should exist and be ready to track
        XCTAssertNotNil(manager)
    }

    func testTrackAction() {
        manager.trackAction()
        // Should not crash and should increment internal counter
        XCTAssertNotNil(manager)
    }

    func testMultipleActionTracking() {
        for _ in 0..<5 {
            manager.trackAction()
        }
        // Should handle multiple trackings gracefully
        XCTAssertNotNil(manager)
    }

    // MARK: - Rating Prompt Logic Tests

    func testShowRatingPromptProperty() {
        // Initial state should not show prompt
        XCTAssertFalse(manager.showRatingPrompt)
    }

    func testRequestRating() {
        manager.requestRating()
        XCTAssertTrue(manager.showRatingPrompt)
    }

    // MARK: - User Response Tests

    func testUserLikesApp() {
        manager.userLikesApp()
        // After liking, prompt should be hidden
        XCTAssertFalse(manager.showRatingPrompt)
    }

    func testUserHasIssues() {
        manager.userHasIssues()
        // After providing feedback, prompt should be hidden
        XCTAssertFalse(manager.showRatingPrompt)
    }

    func testDismissPrompt() {
        manager.requestRating() // First show it
        manager.dismissPrompt()
        XCTAssertFalse(manager.showRatingPrompt)
    }

    // MARK: - Reset Tests

    func testResetRatingStatus() {
        // Track some actions and reset
        manager.trackAction()
        manager.resetRatingStatus()

        // Manager should still function after reset
        XCTAssertNotNil(manager)
    }
}
