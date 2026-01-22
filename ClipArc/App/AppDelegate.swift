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

    let appState = AppState()
    var modelContainer: ModelContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModelContainer()
        setupHotkey()
        setupPanelController()
        setupNotifications()

        NSApp.setActivationPolicy(.accessory)

        // Show onboarding if first launch
        if !appState.hasCompletedOnboarding {
            showOnboarding()
        }
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
            print("Could not create ModelContainer: \(error)")
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
