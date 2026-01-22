//
//  FloatingPanel.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    static let panelHeight: CGFloat = 280

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        configurePanel()
    }

    private func configurePanel() {
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        animationBehavior = .utilityWindow

        hidesOnDeactivate = false
    }

    func setContentView<Content: View>(_ view: Content) {
        let hostingView = NSHostingView(rootView: view)
        contentView = hostingView
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        close()
    }

    func showAtBottom() {
        let screen = Self.targetScreen()

        let screenFrame = screen.frame
        let panelWidth = screenFrame.width
        let panelHeight = Self.panelHeight

        // Position at the bottom of the target screen
        let x = screenFrame.origin.x
        let y = screenFrame.origin.y

        // Start below screen, then animate up
        setFrame(NSRect(x: x, y: y - panelHeight, width: panelWidth, height: panelHeight), display: false)
        alphaValue = 0
        makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
            self.animator().alphaValue = 1
        }
    }

    func hideWithAnimation(completion: (() -> Void)? = nil) {
        let screenFrame = self.frame
        let panelHeight = Self.panelHeight

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().setFrame(NSRect(x: screenFrame.origin.x, y: screenFrame.origin.y - panelHeight, width: screenFrame.width, height: panelHeight), display: true)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            completion?()
        })
    }

    /// Determine which screen to show the panel on
    /// Priority: 1. Screen with active window, 2. Screen with mouse cursor, 3. Main screen
    static func targetScreen() -> NSScreen {
        // Try to get the screen of the frontmost application's key window
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

            for window in windowList {
                if let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                   ownerPID == frontApp.processIdentifier,
                   let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                   let windowX = bounds["X"],
                   let windowY = bounds["Y"],
                   let windowW = bounds["Width"] {
                    // Find screen containing center of this window
                    let windowCenterX = windowX + windowW / 2
                    // CGWindow uses top-left origin, convert to bottom-left for NSScreen
                    let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
                    let flippedY = primaryScreenHeight - windowY

                    for screen in NSScreen.screens {
                        if screen.frame.contains(NSPoint(x: windowCenterX, y: flippedY)) {
                            return screen
                        }
                    }
                }
            }
        }

        // Fallback: screen containing mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }

        // Final fallback: main screen
        return NSScreen.main ?? NSScreen.screens[0]
    }
}
