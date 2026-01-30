//
//  FrictionDetectorTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-30.
//

import XCTest
@testable import ClipArc

@MainActor
final class FrictionDetectorTests: XCTestCase {

    override func setUpWithError() throws {
        // Reset state before each test
        FrictionDetector.shared.resetAllState()
    }

    override func tearDownWithError() throws {
        // Clean up after each test
        FrictionDetector.shared.resetAllState()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsNormal() {
        XCTAssertEqual(FrictionDetector.shared.currentState, .normal)
    }

    // MARK: - Same Item Click Detection Tests

    func testSameItemClicksBelowThreshold() {
        let detector = FrictionDetector.shared
        let itemID = UUID()

        // Click same item 2 times (below threshold of 3)
        detector.trackClick(itemID: itemID)
        detector.trackClick(itemID: itemID)

        XCTAssertEqual(detector.currentState, .normal)
    }

    func testSameItemClicksAtThreshold() {
        let detector = FrictionDetector.shared
        let itemID = UUID()

        // Click same item 3 times (at threshold)
        detector.trackClick(itemID: itemID)
        detector.trackClick(itemID: itemID)
        detector.trackClick(itemID: itemID)

        XCTAssertEqual(detector.currentState, .frictionDetected)
    }

    func testSameItemClicksAboveThreshold() {
        let detector = FrictionDetector.shared
        let itemID = UUID()

        // Click same item 5 times (above threshold)
        for _ in 0..<5 {
            detector.trackClick(itemID: itemID)
        }

        XCTAssertEqual(detector.currentState, .frictionDetected)
    }

    // MARK: - Multi-Item Click Detection Tests

    func testMultiItemClicksBelowThreshold() {
        let detector = FrictionDetector.shared

        // Click 4 different items (below threshold of 5)
        for _ in 0..<4 {
            detector.trackClick(itemID: UUID())
        }

        XCTAssertEqual(detector.currentState, .normal)
    }

    func testMultiItemClicksAtThreshold() {
        let detector = FrictionDetector.shared

        // Click 5 different items (at threshold)
        for _ in 0..<5 {
            detector.trackClick(itemID: UUID())
        }

        XCTAssertEqual(detector.currentState, .frictionDetected)
    }

    // MARK: - Reset Detection Tests

    func testResetDetection() {
        let detector = FrictionDetector.shared
        let itemID = UUID()

        // Trigger friction detection
        for _ in 0..<3 {
            detector.trackClick(itemID: itemID)
        }
        XCTAssertEqual(detector.currentState, .frictionDetected)

        // Reset detection
        detector.resetDetection()

        XCTAssertEqual(detector.currentState, .normal)
    }

    // MARK: - User Dismissed Guide Tests

    func testUserDismissedGuide() {
        let detector = FrictionDetector.shared
        let itemID = UUID()

        // Trigger friction detection
        for _ in 0..<3 {
            detector.trackClick(itemID: itemID)
        }

        // User dismisses guide
        detector.userDismissedGuide()

        XCTAssertEqual(detector.currentState, .cooldown)
    }

    // MARK: - User Accepted Guide Tests

    func testUserAcceptedGuide() {
        let detector = FrictionDetector.shared

        detector.userAcceptedGuide()

        XCTAssertEqual(detector.currentState, .guiding)
    }

    // MARK: - Friction State Enum Tests

    func testFrictionStateValues() {
        // Test that all states are distinct
        let states: [FrictionDetector.FrictionState] = [.normal, .frictionDetected, .guiding, .cooldown]
        let uniqueStates = Set(states.map { String(describing: $0) })
        XCTAssertEqual(uniqueStates.count, 4)
    }
}
