//
//  HotkeyManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var localMonitor: Any?
    private var handler: (() -> Void)?
    private var registeredModifiers: NSEvent.ModifierFlags = []
    private var registeredKeyCode: UInt16 = 0
    private var hasLoggedInitialState = false

    // Signature for our hot key (unique identifier)
    private let hotKeySignature: OSType = {
        let chars = "CLIP".utf8
        var result: OSType = 0
        for char in chars {
            result = (result << 8) | OSType(char)
        }
        return result
    }()

    private static var sharedHandler: (() -> Void)?
    private static var eventHandlerInstalled = false

    func register(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, handler: @escaping () -> Void) {
        self.handler = handler
        self.registeredModifiers = modifiers
        self.registeredKeyCode = keyCode
        HotkeyManager.sharedHandler = handler

        if !hasLoggedInitialState {
            Logger.debug("Registering global hotkey")
            hasLoggedInitialState = true
        }

        // Register Carbon hot key (this properly intercepts and consumes the event)
        // Note: Carbon hot keys do not require accessibility permission
        registerCarbonHotKey(modifiers: modifiers, keyCode: keyCode)

        // Local monitor for events when our app is focused (backup)
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if self?.handleKeyEventReturning(event) == true {
                    return nil // Consume the event
                }
                return event
            }
            Logger.debug("Local monitor registered")
        }
    }

    private func registerCarbonHotKey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        // Unregister existing hot key first
        if let existingRef = hotKeyRef {
            UnregisterEventHotKey(existingRef)
            hotKeyRef = nil
        }

        // Convert NSEvent modifiers to Carbon modifiers
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }

        // Install event handler (only once per app lifecycle)
        if !HotkeyManager.eventHandlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

            let handlerResult = InstallEventHandler(
                GetApplicationEventTarget(),
                { (_, event, _) -> OSStatus in
                    var hotKeyID = EventHotKeyID()
                    let err = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )

                    if err == noErr {
                        Logger.debug("Hotkey triggered!")
                        DispatchQueue.main.async {
                            HotkeyManager.sharedHandler?()
                        }
                    }
                    return noErr
                },
                1,
                &eventType,
                nil,
                nil
            )

            if handlerResult == noErr {
                HotkeyManager.eventHandlerInstalled = true
            } else {
                Logger.error("Failed to install event handler: \(handlerResult)")
            }
        }

        // Register the hot key
        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            Logger.debug("Carbon hot key registered (Cmd+Shift+V)")
        } else {
            Logger.error("Failed to register hot key: \(status)")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            Logger.debug("Carbon hot key unregistered")
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        handler = nil
        HotkeyManager.sharedHandler = nil
    }

    private func handleKeyEventReturning(_ event: NSEvent) -> Bool {
        let requiredModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let activeModifiers = event.modifierFlags.intersection(requiredModifiers)

        guard activeModifiers == registeredModifiers,
              event.keyCode == registeredKeyCode else {
            return false
        }

        Logger.debug("Hotkey triggered (local)!")
        handler?()
        return true
    }

    /// Re-register hot key if needed (e.g., after app becomes active)
    func refreshHotKeyRegistration() {
        Logger.debug("Refreshing hot key registration...")

        if let handler = handler {
            let mods = registeredModifiers
            let code = registeredKeyCode
            unregister()
            register(modifiers: mods, keyCode: code, handler: handler)
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
