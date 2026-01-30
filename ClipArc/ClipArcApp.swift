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
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
            // Pro badge if subscribed
            if appState.isProUser {
                Label {
                    Text("Pro")
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                }

                Divider()
            }

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
                let displayItems = appState.isProUser ? appState.items.prefix(10) : appState.items.prefix(5)
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

                if !appState.isProUser && appState.items.count > 5 {
                    Divider()
                    Button(L10n.Settings.upgradeToPro) {
                        openSettings()
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button(L10n.MenuBar.clearHistory) {
                appState.clearAll()
            }

            Divider()

            // TODO: Re-enable when cloud sync feature is implemented
            // Account section
            // if appState.authManager.isAuthenticated {
            //     HStack {
            //         Image(systemName: "person.circle")
            //         Text(appState.authManager.userName ?? appState.authManager.userEmail ?? "Apple User")
            //             .lineLimit(1)
            //     }
            //     .padding(.horizontal)
            //     .foregroundStyle(.secondary)
            // }

            if !appState.isProUser {
                Button(L10n.Settings.upgradeToPro) {
                    openSettings()
                }
            }

            Button(L10n.MenuBar.preferences) {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

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
    }

}

extension Notification.Name {
    static let showClipboardPanel = Notification.Name("showClipboardPanel")
}
