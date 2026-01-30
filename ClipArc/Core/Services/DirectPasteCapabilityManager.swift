//
//  DirectPasteCapabilityManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-30.
//

import AppKit
import SwiftUI

/// Manages Direct Paste capability state
/// Core principle: Accessibility is a user-initiated enhancement, not a default capability
@MainActor
@Observable
final class DirectPasteCapabilityManager {
    static let shared = DirectPasteCapabilityManager()

    // MARK: - State

    /// Whether the system has granted Accessibility permission
    /// Only uses AXIsProcessTrusted(), never uses WithOptions(prompt: true)
    var isAccessibilityGranted: Bool {
        testIsAccessibilityGranted ?? AXIsProcessTrusted()
    }

    /// Whether the user has explicitly enabled Direct Paste in the app
    /// Stored in UserDefaults - this represents user intent
    private(set) var isUserEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "directPasteModeEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "directPasteModeEnabled")
        }
    }

    /// Whether Direct Paste can be performed
    /// Must satisfy both: user has enabled + system has granted permission
    var canDirectPaste: Bool {
        isUserEnabled && isAccessibilityGranted
    }

    /// Current capability state for UI display
    var capabilityState: CapabilityState {
        if canDirectPaste {
            return .enabled
        } else if isUserEnabled && !isAccessibilityGranted {
            return .pendingPermission
        } else {
            return .disabled
        }
    }

    // MARK: - Actions

    /// User explicitly enables Direct Paste Mode
    /// Only records user intent, does NOT request system permission
    func enableDirectPasteMode() {
        isUserEnabled = true
        Logger.debug("Direct Paste Mode enabled by user")
    }

    /// User disables Direct Paste Mode
    func disableDirectPasteMode() {
        isUserEnabled = false
        Logger.debug("Direct Paste Mode disabled by user")
    }

    /// Opens System Settings → Privacy & Security → Accessibility
    /// ❌ Does NOT use AXIsProcessTrustedWithOptions
    /// User must manually add ClipArc to the list
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            Logger.debug("Opened Accessibility settings")
        }
    }

    /// Check and log current permission status (for debugging)
    func logPermissionStatus() {
        Logger.debug("Accessibility granted: \(isAccessibilityGranted), User enabled: \(isUserEnabled), Can paste: \(canDirectPaste)")
    }

    // MARK: - Types

    enum CapabilityState {
        case disabled           // User hasn't enabled, or explicitly disabled
        case pendingPermission  // User enabled but system permission not granted
        case enabled            // Fully functional

        var displayText: String {
            switch self {
            case .disabled:
                return "Disabled"
            case .pendingPermission:
                return "Pending Permission"
            case .enabled:
                return "Enabled"
            }
        }
    }

    // MARK: - Private

    private init() {
        // Log initial state
        logPermissionStatus()
    }

    // MARK: - Testing Support

    /// For testing: override the accessibility check result
    var testIsAccessibilityGranted: Bool?

    /// Reset all state (for testing)
    func resetAllState() {
        UserDefaults.standard.removeObject(forKey: "directPasteModeEnabled")
        testIsAccessibilityGranted = nil
    }
}
