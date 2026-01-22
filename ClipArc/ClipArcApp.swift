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
    }
}

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Pro badge if subscribed
            if appState.isProUser {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                    Text("Pro")
                        .fontWeight(.medium)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)

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
                        PasteService.pasteItem(item)
                    }) {
                        HStack {
                            Image(systemName: item.type.icon)
                            Text(item.previewText)
                                .lineLimit(1)
                        }
                    }
                }

                if !appState.isProUser && appState.items.count > 5 {
                    Divider()
                    Button(L10n.Settings.upgradeToPro) {
                        openSubscription()
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Divider()

            Button(L10n.MenuBar.clearHistory) {
                appState.clearAll()
            }

            Divider()

            // Account section
            if appState.authManager.isAuthenticated {
                HStack {
                    Image(systemName: "person.circle")
                    Text(appState.authManager.userName ?? appState.authManager.userEmail ?? "Apple User")
                        .lineLimit(1)
                }
                .padding(.horizontal)
                .foregroundStyle(.secondary)
            }

            if !appState.isProUser {
                Button(L10n.Settings.upgradeToPro) {
                    openSubscription()
                }
            }

            SettingsLink {
                Text(L10n.MenuBar.preferences)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button(L10n.MenuBar.quit) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private func openSubscription() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "subscription" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            let subscriptionView = SubscriptionView(subscriptionManager: appState.subscriptionManager)
            let hostingController = NSHostingController(rootView: subscriptionView)
            let window = NSWindow(contentViewController: hostingController)
            window.identifier = NSUserInterfaceItemIdentifier("subscription")
            window.title = L10n.Settings.upgradeToPro
            window.styleMask = [.titled, .closable]
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }
}

extension Notification.Name {
    static let showClipboardPanel = Notification.Name("showClipboardPanel")
}
