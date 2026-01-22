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

    private init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: SettingsKey.historyLimit.rawValue) == nil {
            defaults.set(100, forKey: SettingsKey.historyLimit.rawValue)
        }

        historyLimit = defaults.integer(forKey: SettingsKey.historyLimit.rawValue)
        launchAtLogin = defaults.bool(forKey: SettingsKey.launchAtLogin.rawValue)
        showInDock = defaults.bool(forKey: SettingsKey.showInDock.rawValue)
        soundEnabled = defaults.bool(forKey: SettingsKey.soundEnabled.rawValue)
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
    }
}
