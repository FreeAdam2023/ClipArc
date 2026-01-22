//
//  PasteService.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Carbon.HIToolbox

enum PasteService {
    static func pasteItem(_ item: ClipboardItem, asPlainText: Bool = false) {
        copyToClipboard(item.content, asPlainText: asPlainText)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            simulatePaste()
        }
    }

    static func copyToClipboard(_ content: String, asPlainText: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if asPlainText {
            pasteboard.setString(content, forType: .string)
        } else {
            pasteboard.setString(content, forType: .string)
        }
    }

    static func simulatePaste() {
        guard canSimulatePaste() else {
            showManualPasteAlert()
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)

        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDownEvent?.flags = .maskCommand

        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUpEvent?.flags = .maskCommand

        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }

    static func canSimulatePaste() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private static func showManualPasteAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Content Copied"
            alert.informativeText = "The content has been copied to your clipboard. Press ⌘V to paste it.\n\nTo enable automatic pasting, grant ClipArc accessibility permissions in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openAccessibilitySettings()
            }
        }
    }

    private static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
