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
        // Reset state before each test
        DirectPasteCapabilityManager.shared.resetAllState()
        DirectPasteCapabilityManager.shared.testIsAccessibilityGranted = nil
    }

    override func tearDownWithError() throws {
        // Clean up after each test
        DirectPasteCapabilityManager.shared.resetAllState()
        DirectPasteCapabilityManager.shared.testIsAccessibilityGranted = nil
    }

    // MARK: - Enable/Disable Tests

    func testEnableDirectPasteMode() {
        let manager = DirectPasteCapabilityManager.shared

        manager.enableDirectPasteMode()

        XCTAssertTrue(manager.isUserEnabled)
    }

    func testDisableDirectPasteMode() {
        let manager = DirectPasteCapabilityManager.shared

        manager.enableDirectPasteMode()
        manager.disableDirectPasteMode()

        XCTAssertFalse(manager.isUserEnabled)
    }

    // MARK: - Capability State Tests

    func testCapabilityStateDisabledWhenUserDisabled() {
        let manager = DirectPasteCapabilityManager.shared
        manager.testIsAccessibilityGranted = true

        manager.disableDirectPasteMode()

        XCTAssertEqual(manager.capabilityState, .disabled)
    }

    func testCapabilityStatePendingPermission() {
        let manager = DirectPasteCapabilityManager.shared

        // User enabled, but no accessibility
        manager.enableDirectPasteMode()
        manager.testIsAccessibilityGranted = false

        XCTAssertEqual(manager.capabilityState, .pendingPermission)
    }

    func testCapabilityStateEnabled() {
        let manager = DirectPasteCapabilityManager.shared

        // User enabled AND accessibility granted
        manager.enableDirectPasteMode()
        manager.testIsAccessibilityGranted = true

        XCTAssertEqual(manager.capabilityState, .enabled)
    }

    // MARK: - canDirectPaste Tests

    func testCanDirectPasteWhenBothEnabled() {
        let manager = DirectPasteCapabilityManager.shared

        manager.enableDirectPasteMode()
        manager.testIsAccessibilityGranted = true

        XCTAssertTrue(manager.canDirectPaste)
    }

    func testCannotDirectPasteWhenUserDisabled() {
        let manager = DirectPasteCapabilityManager.shared

        manager.disableDirectPasteMode()
        manager.testIsAccessibilityGranted = true

        XCTAssertFalse(manager.canDirectPaste)
    }

    func testCannotDirectPasteWhenNoAccessibility() {
        let manager = DirectPasteCapabilityManager.shared

        manager.enableDirectPasteMode()
        manager.testIsAccessibilityGranted = false

        XCTAssertFalse(manager.canDirectPaste)
    }

    // MARK: - Display Text Tests

    func testCapabilityStateDisplayText() {
        XCTAssertEqual(DirectPasteCapabilityManager.CapabilityState.disabled.displayText, "Disabled")
        XCTAssertEqual(DirectPasteCapabilityManager.CapabilityState.pendingPermission.displayText, "Pending Permission")
        XCTAssertEqual(DirectPasteCapabilityManager.CapabilityState.enabled.displayText, "Enabled")
    }

    // MARK: - State Transition Tests

    func testStateTransitionFromDisabledToPending() {
        let manager = DirectPasteCapabilityManager.shared
        manager.testIsAccessibilityGranted = false
        manager.disableDirectPasteMode()

        // Start disabled
        XCTAssertEqual(manager.capabilityState, .disabled)

        // User enables
        manager.enableDirectPasteMode()

        // Should be pending (no accessibility)
        XCTAssertEqual(manager.capabilityState, .pendingPermission)
    }

    func testStateTransitionFromPendingToEnabled() {
        let manager = DirectPasteCapabilityManager.shared

        // Start with user enabled but no accessibility
        manager.enableDirectPasteMode()
        manager.testIsAccessibilityGranted = false
        XCTAssertEqual(manager.capabilityState, .pendingPermission)

        // Grant accessibility
        manager.testIsAccessibilityGranted = true

        // Should be enabled
        XCTAssertEqual(manager.capabilityState, .enabled)
    }

    func testStateTransitionFromEnabledToDisabled() {
        let manager = DirectPasteCapabilityManager.shared

        // Start fully enabled
        manager.enableDirectPasteMode()
        manager.testIsAccessibilityGranted = true
        XCTAssertEqual(manager.capabilityState, .enabled)

        // User disables
        manager.disableDirectPasteMode()

        // Should be disabled
        XCTAssertEqual(manager.capabilityState, .disabled)
    }
}
