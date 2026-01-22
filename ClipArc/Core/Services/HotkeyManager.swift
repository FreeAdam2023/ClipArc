//
//  HotkeyManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    private var eventMonitor: Any?
    private var handler: (() -> Void)?
    private var registeredModifiers: NSEvent.ModifierFlags = []
    private var registeredKeyCode: UInt16 = 0

    func register(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, handler: @escaping () -> Void) {
        self.handler = handler
        self.registeredModifiers = modifiers
        self.registeredKeyCode = keyCode

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    func unregister() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        handler = nil
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let requiredModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let activeModifiers = event.modifierFlags.intersection(requiredModifiers)

        guard activeModifiers == registeredModifiers,
              event.keyCode == registeredKeyCode else {
            return
        }

        handler?()
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
