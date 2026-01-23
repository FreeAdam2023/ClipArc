//
//  AppSettingsTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-23.
//

import XCTest
@testable import ClipArc

final class AppSettingsTests: XCTestCase {

    var settings: AppSettings!
    var mockDefaults: MockUserDefaults!

    override func setUpWithError() throws {
        mockDefaults = MockUserDefaults(suiteName: nil)
        settings = AppSettings.shared
    }

    override func tearDownWithError() throws {
        mockDefaults?.reset()
        mockDefaults = nil
    }

    // MARK: - History Limit Tests

    func testDefaultHistoryLimit() {
        // Default should be 100
        XCTAssertEqual(settings.historyLimit, 100)
    }

    func testHistoryLimitPersistence() {
        let newLimit = 200
        settings.historyLimit = newLimit
        XCTAssertEqual(settings.historyLimit, newLimit)
    }

    func testValidHistoryLimits() {
        let validLimits = [50, 100, 200, 500]
        for limit in validLimits {
            settings.historyLimit = limit
            XCTAssertEqual(settings.historyLimit, limit, "Failed for limit: \(limit)")
        }
    }

    // MARK: - Show In Dock Tests

    func testDefaultShowInDock() {
        // Default should be false (accessory mode)
        XCTAssertFalse(settings.showInDock)
    }

    func testShowInDockToggle() {
        settings.showInDock = true
        XCTAssertTrue(settings.showInDock)

        settings.showInDock = false
        XCTAssertFalse(settings.showInDock)
    }

    // MARK: - Appearance Tests

    func testDefaultAppearance() {
        // Default should be system
        XCTAssertEqual(settings.appearance, .system)
    }

    func testAppearanceOptions() {
        let appearances: [AppAppearance] = [.light, .dark, .system]
        for appearance in appearances {
            settings.appearance = appearance
            XCTAssertEqual(settings.appearance, appearance, "Failed for appearance: \(appearance)")
        }
    }

    // MARK: - Sound Settings Tests

    func testDefaultSoundEnabled() {
        // Default should be false
        XCTAssertFalse(settings.soundEnabled)
    }

    func testSoundEnabledToggle() {
        settings.soundEnabled = true
        XCTAssertTrue(settings.soundEnabled)

        settings.soundEnabled = false
        XCTAssertFalse(settings.soundEnabled)
    }

    // MARK: - Reset Tests

    func testResetToDefaults() {
        // Change some settings
        settings.historyLimit = 500
        settings.showInDock = true
        settings.appearance = .dark

        // Reset
        settings.resetToDefaults()

        // Verify defaults
        XCTAssertEqual(settings.historyLimit, 100)
        XCTAssertFalse(settings.showInDock)
        XCTAssertEqual(settings.appearance, .system)
    }
}

// MARK: - AppAppearance Tests

final class AppAppearanceTests: XCTestCase {

    func testAppearanceDisplayNames() {
        XCTAssertEqual(AppAppearance.system.displayName, L10n.Settings.appearanceSystem)
        XCTAssertEqual(AppAppearance.light.displayName, L10n.Settings.appearanceLight)
        XCTAssertEqual(AppAppearance.dark.displayName, L10n.Settings.appearanceDark)
    }

    func testAppearanceAllCases() {
        let allCases = AppAppearance.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.system))
        XCTAssertTrue(allCases.contains(.light))
        XCTAssertTrue(allCases.contains(.dark))
    }
}
