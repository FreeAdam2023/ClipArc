//
//  LocalizationManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-22.
//

import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt-BR"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "language.system", defaultValue: "System Default")
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português (Brasil)"
        case .russian: return "Русский"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            return Locale.current
        default:
            return Locale(identifier: rawValue)
        }
    }
}

@MainActor
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    private let languageKey = "appLanguage"

    var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
            updateBundle()
        }
    }

    private(set) var bundle: Bundle = .main

    private init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            currentLanguage = .system
        }
        updateBundle()
    }

    private func updateBundle() {
        let languageCode: String
        if currentLanguage == .system {
            languageCode = Locale.preferredLanguages.first ?? "en"
        } else {
            languageCode = currentLanguage.rawValue
        }

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            self.bundle = .main
        }
    }

    func localizedString(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    var effectiveLanguageCode: String {
        if currentLanguage == .system {
            return Locale.preferredLanguages.first ?? "en"
        }
        return currentLanguage.rawValue
    }
}

// MARK: - String Extension for Localization

extension String {
    nonisolated var localized: String {
        Bundle.main.localizedString(forKey: self, value: nil, table: nil)
    }

    nonisolated func localized(with arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }
}

// MARK: - Localization Keys

enum L10n {
    // MARK: - Common
    static var appName: String { "app.name".localized }
    static var enable: String { "common.enable".localized }
    static var disable: String { "common.disable".localized }
    static var cancel: String { "common.cancel".localized }
    static var done: String { "common.done".localized }
    static var save: String { "common.save".localized }
    static var delete: String { "common.delete".localized }
    static var copy: String { "common.copy".localized }
    static var paste: String { "common.paste".localized }
    static var search: String { "common.search".localized }
    static var settings: String { "common.settings".localized }
    static var continue_: String { "common.continue".localized }
    static var skip: String { "common.skip".localized }
    static var skipForNow: String { "common.skip_for_now".localized }
    static var edit: String { "common.edit".localized }
    static var selectAll: String { "common.select_all".localized }

    // MARK: - Onboarding
    enum Onboarding {
        static var welcomeTitle: String { "onboarding.welcome.title".localized }
        static var welcomeSubtitle: String { "onboarding.welcome.subtitle".localized }
        static var getStarted: String { "onboarding.welcome.get_started".localized }

        static var featureHistoryTitle: String { "onboarding.feature.history.title".localized }
        static var featureHistoryDesc: String { "onboarding.feature.history.description".localized }
        static var featureSearchTitle: String { "onboarding.feature.search.title".localized }
        static var featureSearchDesc: String { "onboarding.feature.search.description".localized }
        static var featureHotkeyTitle: String { "onboarding.feature.hotkey.title".localized }
        static var featureHotkeyDesc: String { "onboarding.feature.hotkey.description".localized }

        static var permissionsTitle: String { "onboarding.permissions.title".localized }
        static var permissionsSubtitle: String { "onboarding.permissions.subtitle".localized }
        static var accessibilityTitle: String { "onboarding.permissions.accessibility.title".localized }
        static var accessibilityDesc: String { "onboarding.permissions.accessibility.description".localized }
        static var launchAtLoginTitle: String { "onboarding.permissions.launch_at_login.title".localized }
        static var launchAtLoginDesc: String { "onboarding.permissions.launch_at_login.description".localized }

        static var signInTitle: String { "onboarding.signin.title".localized }
        static var signInSubtitle: String { "onboarding.signin.subtitle".localized }
        static var signedInAs: String { "onboarding.signin.signed_in_as".localized }
        static var signInLater: String { "onboarding.signin.sign_in_later".localized }

        static var subscriptionTitle: String { "onboarding.subscription.title".localized }
        static var subscriptionSubtitle: String { "onboarding.subscription.subtitle".localized }
        static var subscribe: String { "onboarding.subscription.subscribe".localized }
        static var startFreeTrial: String { "onboarding.subscription.start_free_trial".localized }
        static var freeVsPro: String { "onboarding.subscription.free_vs_pro".localized }
        static var youArePro: String { "onboarding.subscription.you_are_pro".localized }
        static var save44: String { "onboarding.subscription.save_44".localized }
        static var benefit1: String { "onboarding.subscription.benefit1".localized }
        static var benefit2: String { "onboarding.subscription.benefit2".localized }
        static var benefit3: String { "onboarding.subscription.benefit3".localized }
        static var benefit4: String { "onboarding.subscription.benefit4".localized }

        static var completeTitle: String { "onboarding.complete.title".localized }
        static var completeSubtitle: String { "onboarding.complete.subtitle".localized }
        static var startUsing: String { "onboarding.complete.start_using".localized }
        static var tipOpen: String { "onboarding.complete.tip.open".localized }
        static var tipNavigate: String { "onboarding.complete.tip.navigate".localized }
        static var tipPaste: String { "onboarding.complete.tip.paste".localized }
        static var tipClose: String { "onboarding.complete.tip.close".localized }
    }

    // MARK: - Settings
    enum Settings {
        static var title: String { "settings.title".localized }
        static var general: String { "settings.general".localized }
        static var account: String { "settings.account".localized }
        static var subscription: String { "settings.subscription".localized }
        static var about: String { "settings.about".localized }

        static var historyLimit: String { "settings.history_limit".localized }
        static var items: String { "settings.items".localized }
        static var startup: String { "settings.startup".localized }
        static var launchAtLogin: String { "settings.launch_at_login".localized }
        static var showInDock: String { "settings.show_in_dock".localized }
        static var hotkey: String { "settings.hotkey".localized }
        static var globalHotkey: String { "settings.global_hotkey".localized }
        static var permissions: String { "settings.permissions".localized }
        static var granted: String { "settings.granted".localized }
        static var language: String { "settings.language".localized }
        static var restartRequired: String { "settings.restart_required".localized }

        static var appearance: String { "settings.appearance".localized }
        static var appearanceSystem: String { "settings.appearance.system".localized }
        static var appearanceLight: String { "settings.appearance.light".localized }
        static var appearanceDark: String { "settings.appearance.dark".localized }

        static var signOut: String { "settings.sign_out".localized }
        static var syncDescription: String { "settings.sync_description".localized }
        static var memberAccount: String { "settings.member_account".localized }
        static var signInDescription: String { "settings.sign_in_description".localized }
        static var accountLinked: String { "settings.account_linked".localized }
        static var benefitMembership: String { "settings.benefit_membership".localized }
        static var benefitRestore: String { "settings.benefit_restore".localized }
        static var benefitMultiDevice: String { "settings.benefit_multi_device".localized }
        static var loginRequired: String { "settings.login_required".localized }
        static var loginRequiredMessage: String { "settings.login_required_message".localized }
        static var goToAccount: String { "settings.go_to_account".localized }
        static var accessibilityGuide: String { "settings.accessibility_guide".localized }

        static var proBadge: String { "settings.pro_badge".localized }
        static var lifetimeLicense: String { "settings.lifetime_license".localized }
        static var renewsOn: String { "settings.renews_on".localized }
        static var manageSubscription: String { "settings.manage_subscription".localized }
        static var upgradeToPro: String { "settings.upgrade_to_pro".localized }
        static var upgradeDescription: String { "settings.upgrade_description".localized }
        static var restorePurchases: String { "settings.restore_purchases".localized }

        static var version: String { "settings.version".localized }
        static var aboutDescription: String { "settings.about_description".localized }
        static var support: String { "settings.support".localized }
        static var privacy: String { "settings.privacy".localized }
        static var terms: String { "settings.terms".localized }

        static var storage: String { "settings.storage".localized }
        static var cacheSize: String { "settings.cache_size".localized }
        static var historyItems: String { "settings.history_items".localized }
        static var clearCache: String { "settings.clear_cache".localized }
        static var clearCacheMessage: String { "settings.clear_cache_message".localized }
        static var clearAllHistory: String { "settings.clear_all_history".localized }
        static var clearHistoryMessage: String { "settings.clear_history_message".localized }
        static var clear: String { "settings.clear".localized }

        static var pasteMode: String { "settings.paste_mode".localized }
        static var pasteModeAsk: String { "settings.paste_mode.ask".localized }
        static var pasteModeDirectPaste: String { "settings.paste_mode.direct_paste".localized }
        static var pasteModeCopyOnly: String { "settings.paste_mode.copy_only".localized }
    }

    // MARK: - Clipboard
    enum Clipboard {
        static var emptyTitle: String { "clipboard.empty.title".localized }
        static var emptySubtitle: String { "clipboard.empty.subtitle".localized }
        static var searchPlaceholder: String { "clipboard.search.placeholder".localized }
        static var noResults: String { "clipboard.search.no_results".localized }
        static var copied: String { "clipboard.copied".localized }
        static var pasted: String { "clipboard.pasted".localized }

        static var typeAll: String { "clipboard.type.all".localized }
        static var typeFrequent: String { "clipboard.type.frequent".localized }
        static var typeText: String { "clipboard.type.text".localized }
        static var typeImage: String { "clipboard.type.image".localized }
        static var typeFile: String { "clipboard.type.file".localized }
        static var typeLink: String { "clipboard.type.link".localized }
        static var deleteSelected: String { "clipboard.delete_selected".localized }
    }

    // MARK: - Menu Bar
    enum MenuBar {
        static var showPanel: String { "menu.show_panel".localized }
        static var preferences: String { "menu.preferences".localized }
        static var clearHistory: String { "menu.clear_history".localized }
        static var about: String { "menu.about".localized }
        static var help: String { "menu.help".localized }
        static var quit: String { "menu.quit".localized }
    }

    // MARK: - Rating
    enum Rating {
        static var title: String { "rating.title".localized }
        static var subtitle: String { "rating.subtitle".localized }
        static var yesLoveIt: String { "rating.yes_love_it".localized }
        static var notReally: String { "rating.not_really".localized }
    }

    // MARK: - Errors
    enum Error {
        static var generic: String { "error.generic".localized }
        static var authFailed: String { "error.auth_failed".localized }
        static var purchaseFailed: String { "error.purchase_failed".localized }
        static var networkError: String { "error.network".localized }
    }

    // MARK: - Time
    enum Time {
        static var justNow: String { "time.just_now".localized }
        static var minutesAgo: String { "time.minutes_ago".localized }
        static var hoursAgo: String { "time.hours_ago".localized }
        static var yesterday: String { "time.yesterday".localized }
        static var daysAgo: String { "time.days_ago".localized }
    }

    // MARK: - Toast
    enum Toast {
        static var running: String { "toast.running".localized }
    }

    // MARK: - Paste Dialog
    enum Paste {
        static func directPasteTitle(_ appName: String) -> String {
            "paste.direct_paste_title".localized(with: appName)
        }
        static var directPasteSubtitle: String { "paste.direct_paste_subtitle".localized }
        static var enableDirectPaste: String { "paste.enable_direct_paste".localized }
        static var copyToClipboard: String { "paste.copy_to_clipboard".localized }
        static var dontAskAgain: String { "paste.dont_ask_again".localized }
        static var pressToManualPaste: String { "paste.press_to_manual_paste".localized }
    }

    // MARK: - Accessibility Setup
    enum Accessibility {
        static var setupTitle: String { "accessibility.setup.title".localized }
        static var setupSubtitle: String { "accessibility.setup.subtitle".localized }
        static var openSystemSettings: String { "accessibility.open_system_settings".localized }
        static var havingIssue: String { "accessibility.having_issue".localized }
    }

    // MARK: - Screenshot Monitor
    enum Screenshot {
        static var title: String { "screenshot.title".localized }
        static var subtitle: String { "screenshot.subtitle".localized }
        static var tip: String { "screenshot.tip".localized }
        static var changeFolder: String { "screenshot.change_folder".localized }
        static var info: String { "screenshot.info".localized }
    }

    // MARK: - Direct Paste
    enum DirectPaste {
        static var sectionTitle: String { "direct_paste.section_title".localized }
        static var title: String { "direct_paste.title".localized }
        static var subtitle: String { "direct_paste.subtitle".localized }
        static var enabled: String { "direct_paste.enabled".localized }
        static var enable: String { "direct_paste.enable".localized }
        static var guideTitle: String { "direct_paste.guide_title".localized }
        static var guideSubtitle: String { "direct_paste.guide_subtitle".localized }
        static var whatChanges: String { "direct_paste.what_changes".localized }
        static var requiresAccessibility: String { "direct_paste.requires_accessibility".localized }
        static var manualAddNote: String { "direct_paste.manual_add_note".localized }
        static var skipForNow: String { "direct_paste.skip_for_now".localized }
        static var miniPromptTitle: String { "direct_paste.mini_prompt_title".localized }
        static var miniPromptSubtitle: String { "direct_paste.mini_prompt_subtitle".localized }
        static var maybeLater: String { "direct_paste.maybe_later".localized }
        static var learnHow: String { "direct_paste.learn_how".localized }
        static var benefit1: String { "direct_paste.benefit1".localized }
        static var benefit2: String { "direct_paste.benefit2".localized }
        static var benefit3: String { "direct_paste.benefit3".localized }
    }

    // MARK: - Subscription
    enum Subscription {
        static var upgradeToPro: String { "subscription.upgrade_to_pro".localized }
        static var unlockFullPower: String { "subscription.unlock_full_power".localized }
        static var loadingPrices: String { "subscription.loading_prices".localized }
        static var subscribe: String { "subscription.subscribe".localized }
        static var oneTimePurchase: String { "subscription.one_time_purchase".localized }
        static var cancelAnytime: String { "subscription.cancel_anytime".localized }
        static var autoRenewNote: String { "subscription.auto_renew_note".localized }
        static var bestValue: String { "subscription.best_value".localized }
        static var oneTime: String { "subscription.one_time".localized }
        static var retry: String { "subscription.retry".localized }
        static var restorePurchases: String { "subscription.restore_purchases".localized }
        static var continueFree: String { "subscription.continue_free".localized }
        static var featuresUnlocked: String { "subscription.features_unlocked".localized }
        static var selectPlan: String { "subscription.select_plan".localized }
        static var purchaseLifetime: String { "subscription.purchase_lifetime".localized }
        static var startFreeTrial: String { "subscription.start_free_trial".localized }
        static var freeTrialBadge: String { "subscription.free_trial_badge".localized }
        static var payOnce: String { "subscription.pay_once".localized }
        static var termsOfService: String { "subscription.terms_of_service".localized }
        static var privacyPolicy: String { "subscription.privacy_policy".localized }
        static var perMonth: String { "subscription.per_month".localized }
        static var perYear: String { "subscription.per_year".localized }
        static var perWeek: String { "subscription.per_week".localized }
        static var perDay: String { "subscription.per_day".localized }
        static var featureUnlimitedHistory: String { "subscription.feature.unlimited_history".localized }
        static var featureUnlimitedHistoryDesc: String { "subscription.feature.unlimited_history_desc".localized }
        static var featureAdvancedSearch: String { "subscription.feature.advanced_search".localized }
        static var featureAdvancedSearchDesc: String { "subscription.feature.advanced_search_desc".localized }
        static var featureGlobalHotkey: String { "subscription.feature.global_hotkey".localized }
        static var featureGlobalHotkeyDesc: String { "subscription.feature.global_hotkey_desc".localized }
        static var featureInstantPaste: String { "subscription.feature.instant_paste".localized }
        static var featureInstantPasteDesc: String { "subscription.feature.instant_paste_desc".localized }
    }

    // MARK: - Login
    enum Login {
        static var appName: String { "login.app_name".localized }
        static var tagline: String { "login.tagline".localized }
        static var signInDescription: String { "login.sign_in_description".localized }
        static var subscriptionNote: String { "login.subscription_note".localized }
        static var continueWithoutSignin: String { "login.continue_without_signin".localized }
    }

    // MARK: - Onboarding Additional
    enum OnboardingExtra {
        static var subscriptionNote: String { "onboarding.subscription_note".localized }
    }

    // MARK: - Clipboard Card
    enum Card {
        static var enterKey: String { "card.enter_key".localized }
        static func filesCount(_ count: Int) -> String { "card.files_count".localized(with: count) }
        static func moreFiles(_ count: Int) -> String { "card.more_files".localized(with: count) }
        static func charsCount(_ count: Int) -> String { "card.chars_count".localized(with: count) }
    }

    // MARK: - Accessibility Guide
    enum AccessibilityGuide {
        static var title: String { "accessibility.guide_title".localized }
        static var description: String { "accessibility.guide_description".localized }
    }

    // MARK: - About
    enum About {
        static var copyright: String { "about.copyright".localized }
    }

    // MARK: - Pro Features
    enum ProFeature {
        static var unlimitedHistory: String { "pro.feature.unlimited_history".localized }
        static var advancedSearch: String { "pro.feature.advanced_search".localized }
        static var globalHotkey: String { "pro.feature.global_hotkey".localized }
        static var instantPaste: String { "pro.feature.instant_paste".localized }
    }
}
