//
//  Settings.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Combine
import Foundation

enum SettingsKey: String {
    case historyLimit = "historyLimit"
    case launchAtLogin = "launchAtLogin"
    case showInDock = "showInDock"
    case hotkey = "hotkey"
    case soundEnabled = "soundEnabled"
    case appearance = "appearance"
    case pasteMode = "pasteMode"
    case pasteActionCount = "pasteActionCount"
    case neverAskDirectPaste = "neverAskDirectPaste"
    case maskSensitiveContent = "maskSensitiveContent"
    case skipConcealedContent = "skipConcealedContent"
    case hideFromScreenCapture = "hideFromScreenCapture"
}

/// User's preference for paste behavior when accessibility is not enabled
enum PasteMode: String, CaseIterable {
    case ask = "ask"              // Always ask user (default)
    case directPaste = "direct"   // Always try direct paste (requires accessibility)
    case copyOnly = "copy"        // Always just copy to clipboard

    var displayName: String {
        switch self {
        case .ask: return L10n.Settings.pasteModeAsk
        case .directPaste: return L10n.Settings.pasteModeDirectPaste
        case .copyOnly: return L10n.Settings.pasteModeCopyOnly
        }
    }
}

enum AppAppearance: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return L10n.Settings.appearanceSystem
        case .light: return L10n.Settings.appearanceLight
        case .dark: return L10n.Settings.appearanceDark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var historyLimit: Int {
        didSet {
            UserDefaults.standard.set(historyLimit, forKey: SettingsKey.historyLimit.rawValue)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: SettingsKey.launchAtLogin.rawValue)
        }
    }

    @Published var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: SettingsKey.showInDock.rawValue)
            updateDockVisibility()
        }
    }

    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: SettingsKey.soundEnabled.rawValue)
        }
    }

    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: SettingsKey.appearance.rawValue)
            applyAppearance()
        }
    }

    @Published var pasteMode: PasteMode {
        didSet {
            UserDefaults.standard.set(pasteMode.rawValue, forKey: SettingsKey.pasteMode.rawValue)
        }
    }

    // MARK: - Privacy & Security (all default to on)

    /// Hide passwords, keys, card numbers and other personal data behind a mask
    /// until the user taps to reveal. Never affects copy/paste.
    @Published var maskSensitiveContent: Bool {
        didSet {
            UserDefaults.standard.set(maskSensitiveContent, forKey: SettingsKey.maskSensitiveContent.rawValue)
        }
    }

    /// Do not record clipboard content that the source app marked as concealed or
    /// transient (what password managers set when they copy a credential).
    @Published var skipConcealedContent: Bool {
        didSet {
            UserDefaults.standard.set(skipConcealedContent, forKey: SettingsKey.skipConcealedContent.rawValue)
        }
    }

    /// Exclude the clipboard panel from screen recordings, screen sharing and screenshots.
    @Published var hideFromScreenCapture: Bool {
        didSet {
            UserDefaults.standard.set(hideFromScreenCapture, forKey: SettingsKey.hideFromScreenCapture.rawValue)
        }
    }

    /// Encrypt clipboard text on disk with a key held in this Mac's Keychain.
    /// The key is read through `ClipboardCrypto.settingsKey`, so the model layer
    /// does not have to reach the main actor.
    @Published var encryptHistory: Bool {
        didSet {
            UserDefaults.standard.set(encryptHistory, forKey: ClipboardCrypto.settingsKey)
            if encryptHistory {
                NotificationCenter.default.post(name: .encryptExistingHistory, object: nil)
            }
        }
    }

    /// How long a revealed item stays visible before it masks itself again.
    static let revealTimeout: TimeInterval = 10

    /// Count of paste actions without accessibility permission (for triggering prompt)
    var pasteActionCount: Int {
        get { UserDefaults.standard.integer(forKey: SettingsKey.pasteActionCount.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: SettingsKey.pasteActionCount.rawValue) }
    }

    /// User chose "Don't ask again" for direct paste prompt
    var neverAskDirectPaste: Bool {
        get { UserDefaults.standard.bool(forKey: SettingsKey.neverAskDirectPaste.rawValue) }
        set { UserDefaults.standard.set(newValue, forKey: SettingsKey.neverAskDirectPaste.rawValue) }
    }

    /// Number of paste actions before showing the direct paste prompt
    static let pastePromptThreshold = 3

    private init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: SettingsKey.historyLimit.rawValue) == nil {
            defaults.set(100, forKey: SettingsKey.historyLimit.rawValue)
        }

        // Privacy protections are opt-out: enable them unless the user turned them off.
        for key in [SettingsKey.maskSensitiveContent, .skipConcealedContent, .hideFromScreenCapture]
        where defaults.object(forKey: key.rawValue) == nil {
            defaults.set(true, forKey: key.rawValue)
        }

        historyLimit = defaults.integer(forKey: SettingsKey.historyLimit.rawValue)
        maskSensitiveContent = defaults.bool(forKey: SettingsKey.maskSensitiveContent.rawValue)
        skipConcealedContent = defaults.bool(forKey: SettingsKey.skipConcealedContent.rawValue)
        hideFromScreenCapture = defaults.bool(forKey: SettingsKey.hideFromScreenCapture.rawValue)
        encryptHistory = ClipboardCrypto.isEnabled
        launchAtLogin = defaults.bool(forKey: SettingsKey.launchAtLogin.rawValue)
        showInDock = defaults.bool(forKey: SettingsKey.showInDock.rawValue)
        soundEnabled = defaults.bool(forKey: SettingsKey.soundEnabled.rawValue)

        // Load appearance setting
        if let appearanceRaw = defaults.string(forKey: SettingsKey.appearance.rawValue),
           let savedAppearance = AppAppearance(rawValue: appearanceRaw) {
            appearance = savedAppearance
        } else {
            appearance = .system
        }

        // Load paste mode setting
        if let pasteModeRaw = defaults.string(forKey: SettingsKey.pasteMode.rawValue),
           let savedPasteMode = PasteMode(rawValue: pasteModeRaw) {
            pasteMode = savedPasteMode
        } else {
            pasteMode = .ask
        }

        // Apply appearance on init
        applyAppearance()
    }

    private func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }

    private func updateDockVisibility() {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func resetToDefaults() {
        historyLimit = 100
        launchAtLogin = false
        showInDock = false
        soundEnabled = false
        appearance = .system
        maskSensitiveContent = true
        skipConcealedContent = true
        hideFromScreenCapture = true
        encryptHistory = true
    }
}
