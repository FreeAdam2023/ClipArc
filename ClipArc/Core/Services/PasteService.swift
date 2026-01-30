//
//  PasteService.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//
//  Refactored: 2026-01-30
//  - Removed permission logic (moved to DirectPasteCapabilityManager)
//  - Removed UI dialogs (moved to PasteActionCoordinator)
//  - Now a pure operations layer

import AppKit
import Carbon.HIToolbox

/// Pure clipboard operations service
/// ❌ Does NOT handle permission checks
/// ❌ Does NOT show dialogs/toasts
/// ❌ Does NOT hold state
/// Callers should use PasteActionCoordinator for complete paste flow
@MainActor
enum PasteService {

    // MARK: - Copy Operations

    /// Copy item to clipboard only (without any paste action)
    static func copyItem(_ item: ClipboardItem, asPlainText: Bool = false) {
        Logger.debug("copyItem called - type: \(item.type), content: \(item.content.prefix(50))")

        if item.type == .image, let imageData = item.imageData {
            Logger.debug("Copying image data (\(imageData.count) bytes)")
            copyImageToClipboard(imageData)
        } else if item.type == .file, !item.fileURLs.isEmpty {
            Logger.debug("Copying \(item.fileURLs.count) file(s)")
            copyFilesToClipboard(item.fileURLs)
        } else {
            Logger.debug("Copying text content")
            copyToClipboard(item.content, asPlainText: asPlainText)
        }
    }

    /// Copy text to clipboard
    static func copyToClipboard(_ content: String, asPlainText: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(content, forType: .string)
        Logger.debug("copyToClipboard success: \(success), content length: \(content.count)")
    }

    /// Copy image data to clipboard
    static func copyImageToClipboard(_ imageData: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(imageData, forType: .png)
        if let image = NSImage(data: imageData) {
            pasteboard.writeObjects([image])
        }
    }

    /// Copy file URLs to clipboard
    static func copyFilesToClipboard(_ fileURLs: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(fileURLs as [NSURL])
    }

    // MARK: - Paste Simulation

    /// Simulate Cmd+V keystroke
    /// ⚠️ Caller MUST ensure DirectPasteCapabilityManager.canDirectPaste == true
    /// This method does NOT check permissions
    static func simulateCmdV() {
        Logger.debug("Simulating Cmd+V...")

        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitLocalKeyboardEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let vCode = CGKeyCode(kVK_ANSI_V)

        guard let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: true),
              let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: vCode, keyDown: false) else {
            Logger.error("Failed to create keyboard events")
            return
        }

        keyVDown.flags = .maskCommand
        keyVUp.flags = .maskCommand

        keyVDown.post(tap: .cghidEventTap)
        usleep(10000)  // 10ms delay
        keyVUp.post(tap: .cghidEventTap)

        Logger.debug("Paste events posted")
    }

    // MARK: - Deprecated Methods (for migration reference)
    // The following methods have been moved to other components:
    //
    // requestAccessibilityPermission() → Removed (violates App Store guidelines)
    // canSimulatePaste() → DirectPasteCapabilityManager.isAccessibilityGranted
    // openAccessibilitySettings() → DirectPasteCapabilityManager.openAccessibilitySettings()
    // pasteItem() → PasteActionCoordinator.performPaste()
    // showPasteChoiceDialog() → Removed (replaced by friction-based guide)
    // showCopiedToast() → PasteActionCoordinator.showCopiedToast()
    // showAccessibilitySetupView() → Triggered via NotificationCenter
}
