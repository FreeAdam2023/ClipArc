//
//  DirectPasteCapabilityManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-30.
//

import AppKit
import SwiftUI

/// Manages Direct Paste capability state
/// Simplified: Accessibility permission granted = Direct Paste enabled
/// User manually grants permission in System Settings = user-initiated
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

    /// Whether Direct Paste can be performed
    /// Simplified: just check if Accessibility permission is granted
    /// User granting permission in System Settings IS the user intent
    var canDirectPaste: Bool {
        isAccessibilityGranted
    }

    /// Current capability state for UI display
    var capabilityState: CapabilityState {
        isAccessibilityGranted ? .enabled : .disabled
    }

    // MARK: - Actions

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
        Logger.debug("Accessibility granted: \(isAccessibilityGranted), Can Direct Paste: \(canDirectPaste)")
    }

    // MARK: - Types

    enum CapabilityState {
        case disabled  // No Accessibility permission
        case enabled   // Accessibility granted, Direct Paste works

        var displayText: String {
            switch self {
            case .disabled:
                return "Disabled"
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
        testIsAccessibilityGranted = nil
    }
}
