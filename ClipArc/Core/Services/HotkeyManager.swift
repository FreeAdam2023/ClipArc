//
//  HotkeyManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var handler: (() -> Void)?
    private var registeredModifiers: NSEvent.ModifierFlags = []
    private var registeredKeyCode: UInt16 = 0
    private var hasAccessibilityPermission = false
    private var hasLoggedInitialState = false

    func register(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, handler: @escaping () -> Void) {
        self.handler = handler
        self.registeredModifiers = modifiers
        self.registeredKeyCode = keyCode

        // Check if we have accessibility permission
        let hasAccessibility = AXIsProcessTrusted()
        hasAccessibilityPermission = hasAccessibility

        if !hasLoggedInitialState {
            print("[HotkeyManager] Accessibility permission: \(hasAccessibility)")
            hasLoggedInitialState = true
        }

        // Global monitor for events when other apps are focused
        // NOTE: This requires Accessibility permission!
        if hasAccessibility {
            if globalMonitor == nil {
                globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    self?.handleKeyEvent(event)
                }
                print("[HotkeyManager] Global monitor registered")
            }
        } else if !hasLoggedInitialState {
            print("[HotkeyManager] ⚠️ No accessibility permission - global hotkey won't work!")
            print("[HotkeyManager] Please enable Accessibility in System Settings > Privacy & Security > Accessibility")
        }

        // Local monitor for events when our app is focused
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if self?.handleKeyEventReturning(event) == true {
                    return nil // Consume the event
                }
                return event
            }
            print("[HotkeyManager] Local monitor registered")
        }
    }

    func unregister() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        handler = nil
    }

    private func handleKeyEvent(_ event: NSEvent) {
        _ = handleKeyEventReturning(event)
    }

    private func handleKeyEventReturning(_ event: NSEvent) -> Bool {
        let requiredModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let activeModifiers = event.modifierFlags.intersection(requiredModifiers)

        guard activeModifiers == registeredModifiers,
              event.keyCode == registeredKeyCode else {
            return false
        }

        print("[HotkeyManager] Hotkey triggered!")
        handler?()
        return true
    }

    /// Re-register monitors after accessibility permission is granted
    func refreshAfterPermissionChange() {
        let currentPermission = AXIsProcessTrusted()

        // Only refresh if permission state actually changed (from false to true)
        guard currentPermission && !hasAccessibilityPermission else { return }

        print("[HotkeyManager] Accessibility permission granted! Registering global monitor...")

        let currentHandler = handler
        let currentModifiers = registeredModifiers
        let currentKeyCode = registeredKeyCode

        unregister()
        hasLoggedInitialState = false  // Allow logging the new state

        if let handler = currentHandler {
            register(modifiers: currentModifiers, keyCode: currentKeyCode, handler: handler)
        }
    }

    deinit {
        unregister()
    }
}

enum KeyCode {
    static let v: UInt16 = 9
    static let c: UInt16 = 8
    static let escape: UInt16 = 53
    static let returnKey: UInt16 = 36
    static let upArrow: UInt16 = 126
    static let downArrow: UInt16 = 125
    static let tab: UInt16 = 48
}
