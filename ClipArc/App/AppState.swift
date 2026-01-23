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
    var selectedType: ClipboardItemType? = nil  // nil means "All"
    var showFrequentOnly = false  // Show only frequently used items
    var selectedIndex = 0
    var items: [ClipboardItem] = []
    var scrollToSelectedTrigger = UUID()  // Changes to trigger scroll

    // Selection mode for batch operations
    var isSelectionMode = false
    var selectedItemIDs: Set<UUID> = []

    // Auth & Subscription
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    var authManager: AuthManager { AuthManager.shared }
    var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }

    // Free tier: 5 items limit (referenced from ClipboardStore)
    static var freeHistoryLimit: Int { ClipboardStore.freeHistoryLimit }

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

        clipboardMonitor?.onNewContent = { [weak self] clipboardContent in
            guard let self = self else { return }

            let frontmostApp = NSWorkspace.shared.frontmostApplication
            let bundleID = frontmostApp?.bundleIdentifier
            let appName = frontmostApp?.localizedName

            switch clipboardContent {
            case .text(let content, let type):
                if let item = self.clipboardStore?.add(
                    content: content,
                    type: type,
                    sourceAppBundleID: bundleID,
                    sourceAppName: appName
                ) {
                    // Fetch URL title asynchronously for URL items
                    if type == .url && item.urlTitle == nil {
                        Task {
                            await self.fetchURLTitle(for: item)
                        }
                    }
                }
            case .image(let data, let width, let height):
                self.clipboardStore?.addImage(
                    data: data,
                    width: width,
                    height: height,
                    sourceAppBundleID: bundleID,
                    sourceAppName: appName
                )
            case .files(let urls):
                self.clipboardStore?.addFiles(
                    urls: urls,
                    sourceAppBundleID: bundleID,
                    sourceAppName: appName
                )
            }
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

    // MARK: - Selection Mode

    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedItemIDs.removeAll()
        }
    }

    func toggleItemSelection(_ item: ClipboardItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    func selectAllItems() {
        selectedItemIDs = Set(filteredItems.map { $0.id })
    }

    func deselectAllItems() {
        selectedItemIDs.removeAll()
    }

    func deleteSelectedItems() {
        let itemsToDelete = items.filter { selectedItemIDs.contains($0.id) }
        for item in itemsToDelete {
            clipboardStore?.delete(item)
        }
        selectedItemIDs.removeAll()
        isSelectionMode = false
        refreshItems()
    }

    var selectedCount: Int {
        selectedItemIDs.count
    }

    /// Move item to front by updating its timestamp and increment use count (called when item is pasted)
    func touchItem(_ item: ClipboardItem) {
        item.createdAt = Date()
        item.useCount += 1
        refreshItems()
    }

    func clearAll() {
        clipboardStore?.clear()
        refreshItems()
    }

    func showPanel() {
        isPanelVisible = true
        searchQuery = ""
        selectedType = nil
        showFrequentOnly = false
        selectedIndex = 0
        refreshItems()
    }

    func hidePanel() {
        isPanelVisible = false
        searchQuery = ""
        selectedType = nil
        showFrequentOnly = false
        isSelectionMode = false
        selectedItemIDs.removeAll()
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
            scrollToSelectedTrigger = UUID()  // Trigger scroll
        }
    }

    func moveSelectionDown() {
        let maxIndex = filteredItems.count - 1
        if selectedIndex < maxIndex {
            selectedIndex += 1
            scrollToSelectedTrigger = UUID()  // Trigger scroll
        }
    }

    var filteredItems: [ClipboardItem] {
        var result = items

        // Filter by frequent only
        if showFrequentOnly {
            result = result.filter { $0.isFrequent }
            // Sort by use count (most used first) when showing frequent
            result.sort { $0.useCount > $1.useCount }
        }

        // Filter by type if selected
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            result = result.filter { item in
                item.content.localizedCaseInsensitiveContains(searchQuery) ||
                item.previewText.localizedCaseInsensitiveContains(searchQuery) ||
                (item.urlTitle?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }

        return result
    }

    /// Check if there are any frequent items
    var hasFrequentItems: Bool {
        items.contains { $0.isFrequent }
    }

    /// Get available types from current items for filter tabs
    var availableTypes: [ClipboardItemType] {
        let types = Set(items.map { $0.type })
        // Return in a logical order
        return ClipboardItemType.allCases.filter { types.contains($0) }
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

    // MARK: - URL Title Fetching

    /// Fetch and update the page title for a URL item
    private func fetchURLTitle(for item: ClipboardItem) async {
        print("[AppState] fetchURLTitle called for: \(item.content.prefix(50))")
        guard item.type == .url, item.urlTitle == nil else {
            print("[AppState] Skipping - type: \(item.type), urlTitle: \(item.urlTitle ?? "nil")")
            return
        }

        print("[AppState] Fetching title from URLMetadataService...")
        if let title = await URLMetadataService.shared.fetchTitle(for: item.content) {
            print("[AppState] Got title: \(title)")
            // Update on main actor
            await MainActor.run {
                item.urlTitle = title
                print("[AppState] Set urlTitle and refreshing items")
                // Trigger UI refresh
                self.refreshItems()
            }
        } else {
            print("[AppState] Failed to fetch title")
        }
    }
}
