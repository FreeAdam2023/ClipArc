//
//  ClipArcApp.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct ClipArcApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ClipboardItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            Logger.notice("sharedModelContainer created successfully (ClipArcApp)")
            return container
        } catch {
            Logger.error("sharedModelContainer persistent init failed; falling back to in-memory", error: error)
            do {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                Logger.fault("In-memory ModelContainer also failed", error: error)
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    @State private var showOnboarding = false

    var body: some Scene {
        MenuBarExtra("ClipArc", systemImage: "clipboard") {
            MenuBarContentView()
                .environment(appDelegate.appState)
                .modelContainer(sharedModelContainer)
        }

        Settings {
            SettingsView()
                .environment(appDelegate.appState)
        }

        Window("Welcome to ClipArc", id: "onboarding") {
            OnboardingView(appState: appDelegate.appState) {
                NSApplication.shared.keyWindow?.close()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove the default About menu item
            CommandGroup(replacing: .appInfo) { }
        }
    }
}

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettingsAction

    /// Opens the Settings window and brings it to front
    private func openSettings() {
        openSettingsAction()
        // Activate after opening to ensure window comes to front
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func menuPreview(for item: ClipboardItem) -> String {
        let text = item.previewText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if text.count <= 50 {
            return text
        }
        return String(text.prefix(47)) + "..."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(L10n.MenuBar.showPanel) {
                appState.showPanel()
                NotificationCenter.default.post(name: .showClipboardPanel, object: nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Divider()

            if appState.items.isEmpty {
                Text(L10n.Clipboard.emptyTitle)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                let displayItems = appState.items.prefix(10)
                ForEach(displayItems) { item in
                    Button(action: {
                        PasteActionCoordinator.shared.performPaste(item: item)
                    }) {
                        HStack {
                            Image(systemName: item.type.icon)
                            Text(menuPreview(for: item))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
            }

            Divider()

            Button(L10n.MenuBar.clearHistory) {
                appState.clearAll()
            }

            Divider()

            Button(L10n.MenuBar.preferences) {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button(L10n.MenuBar.help) {
                if let url = URL(string: "https://www.versegates.com/cliparc/support") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button(L10n.MenuBar.quit) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsWindow)) { _ in
            openSettings()
        }
    }

}

extension Notification.Name {
    static let showClipboardPanel = Notification.Name("showClipboardPanel")
    static let openSettingsWindow = Notification.Name("openSettingsWindow")
}
