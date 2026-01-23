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

    private init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: SettingsKey.historyLimit.rawValue) == nil {
            defaults.set(100, forKey: SettingsKey.historyLimit.rawValue)
        }

        historyLimit = defaults.integer(forKey: SettingsKey.historyLimit.rawValue)
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
    }
}
