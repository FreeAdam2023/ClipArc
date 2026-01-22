//
//  AppState.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class AppState {
    var isPanelVisible = false
    var searchQuery = ""
    var selectedIndex = 0
    var items: [ClipboardItem] = []

    // Auth & Subscription
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    var authManager: AuthManager { AuthManager.shared }
    var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }

    // Free tier: 5 items limit
    static let freeHistoryLimit = 5

    var canUseApp: Bool {
        return subscriptionManager.isPro || items.count <= Self.freeHistoryLimit
    }

    var isProUser: Bool {
        subscriptionManager.isPro
    }

    var displayItems: [ClipboardItem] {
        if isProUser {
            return items
        } else {
            return Array(items.prefix(Self.freeHistoryLimit))
        }
    }

    private var clipboardMonitor: ClipboardMonitor?
    private var clipboardStore: ClipboardStore?

    func setup(modelContext: ModelContext) {
        clipboardStore = ClipboardStore(modelContext: modelContext)
        clipboardMonitor = ClipboardMonitor()

        clipboardMonitor?.onNewContent = { [weak self] content, type in
            guard let self = self else { return }

            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let bundleID = frontmostApp?.bundleIdentifier
            let appName = frontmostApp?.localizedName

            self.clipboardStore?.add(
                content: content,
                type: type,
                sourceAppBundleID: bundleID,
                sourceAppName: appName
            )
            self.refreshItems()
        }

        clipboardMonitor?.startMonitoring()
        refreshItems()
    }

    func refreshItems() {
        items = clipboardStore?.fetchAll() ?? []
    }

    func deleteItem(_ item: ClipboardItem) {
        clipboardStore?.delete(item)
        refreshItems()
    }

    func clearAll() {
        clipboardStore?.clear()
        refreshItems()
    }

    func showPanel() {
        isPanelVisible = true
        searchQuery = ""
        selectedIndex = 0
        refreshItems()
    }

    func hidePanel() {
        isPanelVisible = false
        searchQuery = ""
    }

    func togglePanel() {
        if isPanelVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func moveSelectionUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    func moveSelectionDown() {
        let maxIndex = filteredItems.count - 1
        if selectedIndex < maxIndex {
            selectedIndex += 1
        }
    }

    var filteredItems: [ClipboardItem] {
        guard !searchQuery.isEmpty else { return items }
        return items.filter { item in
            item.content.localizedCaseInsensitiveContains(searchQuery) ||
            item.previewText.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var selectedItem: ClipboardItem? {
        guard selectedIndex >= 0 && selectedIndex < filteredItems.count else {
            return nil
        }
        return filteredItems[selectedIndex]
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
