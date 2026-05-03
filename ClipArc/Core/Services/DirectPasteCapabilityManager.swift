//
//  DirectPasteCapabilityManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-30.
//

import AppKit
import SwiftUI

/// Manages Direct Paste capability state
/// - App Store version: Direct Paste is disabled (sandbox restrictions)
/// - Direct version: Accessibility permission granted = Direct Paste enabled
@MainActor
@Observable
final class DirectPasteCapabilityManager {
    static let shared = DirectPasteCapabilityManager()

    // MARK: - State

    /// Whether the system has granted Accessibility permission
    /// Only uses AXIsProcessTrusted(), never uses WithOptions(prompt: true)
    var isAccessibilityGranted: Bool {
        #if APPSTORE
        return false  // App Store version cannot use Accessibility API
        #else
        return testIsAccessibilityGranted ?? AXIsProcessTrusted()
        #endif
    }

    /// Whether Direct Paste can be performed
    /// - App Store: Always false (feature not available)
    /// - Direct: Check Accessibility permission + user setting
    var canDirectPaste: Bool {
        #if APPSTORE
        return false
        #else
        return isAccessibilityGranted && AppSettings.shared.pasteMode == .directPaste
        #endif
    }

    /// Current capability state for UI display
    var capabilityState: CapabilityState {
        isAccessibilityGranted ? .enabled : .disabled
    }

    // MARK: - Actions

    /// Opens System Settings → Privacy & Security → Accessibility
    /// ❌ Does NOT use AXIsProcessTrustedWithOptions
    /// User must manually add ClipArc to the list
    /// Note: Only available in Direct distribution version
    func openAccessibilitySettings() {
        #if APPSTORE
        Logger.debug("Accessibility settings not available in App Store version")
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            Logger.debug("Opened Accessibility settings")
        }
        #endif
    }

    /// Whether Direct Paste feature is available in this build
    static var isDirectPasteAvailable: Bool {
        #if APPSTORE
        return false
        #else
        return true
        #endif
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
