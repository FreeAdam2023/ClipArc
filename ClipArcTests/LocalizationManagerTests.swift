//
//  LocalizationManagerTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-23.
//

import XCTest
@testable import ClipArc

final class LocalizationManagerTests: XCTestCase {

    var manager: LocalizationManager!

    override func setUpWithError() throws {
        manager = LocalizationManager.shared
    }

    override func tearDownWithError() throws {
        manager = nil
    }

    // MARK: - Language Tests

    func testDefaultLanguage() {
        // Should return a valid language
        XCTAssertNotNil(manager.currentLanguage)
    }

    func testAllLanguagesAvailable() {
        let allLanguages = AppLanguage.allCases
        XCTAssertFalse(allLanguages.isEmpty)
        XCTAssertTrue(allLanguages.contains(.english))
    }

    func testLanguageSwitching() {
        let originalLanguage = manager.currentLanguage

        // Switch to a different language
        let newLanguage: AppLanguage = originalLanguage == .english ? .chineseSimplified : .english
        manager.currentLanguage = newLanguage

        XCTAssertEqual(manager.currentLanguage, newLanguage)

        // Restore original
        manager.currentLanguage = originalLanguage
    }

    // MARK: - Display Name Tests

    func testLanguageDisplayNames() {
        for language in AppLanguage.allCases {
            XCTAssertFalse(language.displayName.isEmpty,
                          "Language \(language) should have a display name")
        }
    }

    func testEnglishDisplayName() {
        XCTAssertEqual(AppLanguage.english.displayName, "English")
    }

    func testChineseDisplayNames() {
        XCTAssertEqual(AppLanguage.chineseSimplified.displayName, "简体中文")
        XCTAssertEqual(AppLanguage.chineseTraditional.displayName, "繁體中文")
    }

    // MARK: - Language Raw Value Tests

    func testLanguageRawValues() {
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
        XCTAssertEqual(AppLanguage.chineseSimplified.rawValue, "zh-Hans")
        XCTAssertEqual(AppLanguage.chineseTraditional.rawValue, "zh-Hant")
    }

    // MARK: - Localization String Tests

    func testAppNameLocalization() {
        XCTAssertFalse(L10n.appName.isEmpty)
    }

    func testCommonStringsExist() {
        // Test that common strings are properly localized
        XCTAssertFalse(L10n.continue_.isEmpty)
        XCTAssertFalse(L10n.cancel.isEmpty)
        XCTAssertFalse(L10n.delete.isEmpty)
        XCTAssertFalse(L10n.enable.isEmpty)
    }

    func testSettingsStringsExist() {
        XCTAssertFalse(L10n.Settings.general.isEmpty)
        XCTAssertFalse(L10n.Settings.account.isEmpty)
        XCTAssertFalse(L10n.Settings.subscription.isEmpty)
        XCTAssertFalse(L10n.Settings.about.isEmpty)
    }

    func testOnboardingStringsExist() {
        XCTAssertFalse(L10n.Onboarding.welcomeTitle.isEmpty)
        XCTAssertFalse(L10n.Onboarding.getStarted.isEmpty)
    }
}
