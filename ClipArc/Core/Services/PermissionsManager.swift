//
//  PermissionsManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Foundation
import ServiceManagement

@MainActor
@Observable
final class PermissionsManager {
    static let shared = PermissionsManager()

    var isLaunchAtLoginEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            setLaunchAtLogin(newValue)
        }
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    private init() {}

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }

    func toggleLaunchAtLogin() {
        isLaunchAtLoginEnabled.toggle()
    }

    // MARK: - Accessibility Permission

    func requestAccessibilityPermission() {
        // Try to prompt the system dialog first
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        // If not trusted and no dialog appeared (e.g., during development),
        // open System Settings directly
        if !trusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                // Check again - if still not trusted and app not in list, open settings
                if !AXIsProcessTrusted() {
                    self?.openAccessibilitySettings()
                }
            }
        }
    }

    func openAccessibilitySettings() {
        // macOS 13+ (Ventura) and later use the new System Settings app
        // Try the new URL scheme first, then fall back to older methods
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        ]

        for urlString in urls {
            if let url = URL(string: urlString) {
                let success = NSWorkspace.shared.open(url)
                if success {
                    return
                }
            }
        }

        // Fallback: open System Settings Privacy & Security pane
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Permission Status

    var allPermissionsGranted: Bool {
        hasAccessibilityPermission
    }

    var permissionsSummary: String {
        var summary: [String] = []

        if !hasAccessibilityPermission {
            summary.append("Accessibility (for auto-paste)")
        }

        if summary.isEmpty {
            return "All permissions granted"
        } else {
            return "Missing: \(summary.joined(separator: ", "))"
        }
    }
}
