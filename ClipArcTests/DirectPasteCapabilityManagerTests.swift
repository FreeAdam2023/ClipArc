//
//  DirectPasteCapabilityManagerTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-30.
//

import XCTest
@testable import ClipArc

@MainActor
final class DirectPasteCapabilityManagerTests: XCTestCase {

    override func setUpWithError() throws {
        DirectPasteCapabilityManager.shared.resetAllState()
    }

    override func tearDownWithError() throws {
        DirectPasteCapabilityManager.shared.resetAllState()
    }

    // MARK: - Capability State Tests

    func testCapabilityStateDisabledWhenNoAccessibility() {
        let manager = DirectPasteCapabilityManager.shared
        manager.testIsAccessibilityGranted = false

        XCTAssertEqual(manager.capabilityState, .disabled)
    }

    func testCapabilityStateEnabledWhenAccessibilityGranted() {
        let manager = DirectPasteCapabilityManager.shared
        manager.testIsAccessibilityGranted = true

        XCTAssertEqual(manager.capabilityState, .enabled)
    }

    // MARK: - canDirectPaste Tests

    func testCanDirectPasteWhenAccessibilityGranted() {
        let manager = DirectPasteCapabilityManager.shared
        manager.testIsAccessibilityGranted = true

        XCTAssertTrue(manager.canDirectPaste)
    }

    func testCannotDirectPasteWhenNoAccessibility() {
        let manager = DirectPasteCapabilityManager.shared
        manager.testIsAccessibilityGranted = false

        XCTAssertFalse(manager.canDirectPaste)
    }

    // MARK: - Display Text Tests

    func testCapabilityStateDisplayText() {
        XCTAssertEqual(DirectPasteCapabilityManager.CapabilityState.disabled.displayText, "Disabled")
        XCTAssertEqual(DirectPasteCapabilityManager.CapabilityState.enabled.displayText, "Enabled")
    }

    // MARK: - isAccessibilityGranted Tests

    func testIsAccessibilityGrantedReflectsTestValue() {
        let manager = DirectPasteCapabilityManager.shared

        manager.testIsAccessibilityGranted = true
        XCTAssertTrue(manager.isAccessibilityGranted)

        manager.testIsAccessibilityGranted = false
        XCTAssertFalse(manager.isAccessibilityGranted)
    }
}
