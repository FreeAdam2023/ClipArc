//
//  AppDelegate.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import SwiftUI
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: FloatingPanelController?
    private var hotkeyManager: HotkeyManager?
    private var onboardingWindow: NSWindow?
    private var startupToast: StartupToastController?

    let appState = AppState()
    var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModelContainer()
        setupHotkey()
        setupPanelController()
        setupNotifications()
        setupDirectPasteGuide()
        setupScreenshotMonitor()

        NSApp.setActivationPolicy(.accessory)

        // Show onboarding if first launch, otherwise show startup toast
        if !appState.hasCompletedOnboarding {
            showOnboarding()
        } else {
            showStartupToast()
        }
    }

    private func setupDirectPasteGuide() {
        // Initialize DirectPasteGuideController to set up notification observers
        _ = DirectPasteGuideController.shared
    }

    private func setupScreenshotMonitor() {
        let monitor = ScreenshotMonitor.shared

        // Connect screenshot monitor to clipboard store
        monitor.onNewScreenshot = { [weak self] imageData, width, height in
            Task { @MainActor in
                self?.appState.addScreenshot(imageData: imageData, width: width, height: height)
                Logger.debug("Screenshot added to clipboard history")
            }
        }

        // Start monitoring if enabled
        monitor.startMonitoringIfEnabled()

        // Listen for screenshot monitor prompt notification
        NotificationCenter.default.addObserver(
            forName: .showScreenshotMonitorPrompt,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showScreenshotMonitorPrompt()
            }
        }
    }

    private var screenshotPromptWindow: NSWindow?

    private func showScreenshotMonitorPrompt() {
        // Don't show if already showing
        guard screenshotPromptWindow == nil else { return }

        let promptView = ScreenshotMonitorPromptView(
            onEnable: { [weak self] in
                ScreenshotMonitor.shared.selectFolder()
                self?.dismissScreenshotPrompt()
            },
            onDismiss: { [weak self] in
                UserDefaults.standard.set(true, forKey: "screenshotMonitorPromptDismissed")
                self?.dismissScreenshotPrompt()
            },
            onLater: { [weak self] in
                self?.dismissScreenshotPrompt()
            }
        )

        let hostingView = NSHostingView(rootView: promptView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 140)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating

        // Position at top right of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 340
            let y = screenFrame.maxY - 160
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window.orderFrontRegardless()
        screenshotPromptWindow = window

        // Auto dismiss after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.dismissScreenshotPrompt()
        }
    }

    private func dismissScreenshotPrompt() {
        screenshotPromptWindow?.close()
        screenshotPromptWindow = nil
    }

    private func showStartupToast() {
        startupToast = StartupToastController()
        startupToast?.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregister()
    }

    private func setupModelContainer() {
        let schema = Schema([ClipboardItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            if let context = modelContainer?.mainContext {
                appState.setup(modelContext: context)
            }
        } catch {
            Logger.error("Could not create ModelContainer", error: error)
        }
    }

    private func setupHotkey() {
        hotkeyManager = HotkeyManager()

        hotkeyManager?.register(
            modifiers: [.command, .shift],
            keyCode: KeyCode.v
        ) { [weak self] in
            Task { @MainActor in
                self?.togglePanel()
            }
        }
    }

    private func setupPanelController() {
        guard let container = modelContainer else { return }
        panelController = FloatingPanelController(appState: appState, modelContainer: container)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPanelNotification),
            name: .showClipboardPanel,
            object: nil
        )
    }

    @objc private func showPanelNotification() {
        showPanel()
    }

    private func togglePanel() {
        if panelController == nil {
            setupPanelController()
        }
        panelController?.toggle()
    }

    private func showPanel() {
        if panelController == nil {
            setupPanelController()
        }
        panelController?.show()
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView(appState: appState) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }

        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to ClipArc"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        onboardingWindow = window
    }
}
