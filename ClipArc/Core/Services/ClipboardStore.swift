//
//  ClipboardStore.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class ClipboardStore: ObservableObject {
    private let modelContext: ModelContext
    private let proHistoryLimit: Int
    static let freeHistoryLimit = 9

    // Content size limit for text (in bytes)
    static let maxContentSize = 1 * 1024 * 1024    // 1 MB for text content

    /// Returns the effective history limit based on subscription status
    private var effectiveLimit: Int {
        SubscriptionManager.shared.isPro ? proHistoryLimit : Self.freeHistoryLimit
    }

    init(modelContext: ModelContext, historyLimit: Int = 100) {
        self.modelContext = modelContext
        self.proHistoryLimit = historyLimit
    }

    /// Add content to the store and return the item (for URL title fetching)
    @discardableResult
    func add(content: String, type: ClipboardItemType, sourceAppBundleID: String? = nil, sourceAppName: String? = nil) -> ClipboardItem? {
        // Check content size - skip if too large
        let contentSize = content.utf8.count
        guard contentSize <= Self.maxContentSize else {
            print("[ClipboardStore] Content too large (\(contentSize) bytes), skipping. Limit: \(Self.maxContentSize) bytes")
            return nil
        }

        let hash = ClipboardItem.computeHash(content)
        let resultItem: ClipboardItem

        if let existing = findByHash(hash) {
            existing.createdAt = Date()
            existing.sourceAppBundleID = sourceAppBundleID
            existing.sourceAppName = sourceAppName
            resultItem = existing
        } else {
            let item = ClipboardItem(
                content: content,
                type: type,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName
            )
            modelContext.insert(item)
            resultItem = item
        }

        saveAndEnforceLimit()
        return resultItem
    }

    /// Add image content to the store
    func addImage(data: Data, width: Int, height: Int, sourceAppBundleID: String? = nil, sourceAppName: String? = nil) {
        let hash = ClipboardItem.computeHashFromData(data)

        if let existing = findByHash(hash) {
            // Update existing image item
            existing.createdAt = Date()
            existing.sourceAppBundleID = sourceAppBundleID
            existing.sourceAppName = sourceAppName
        } else {
            let item = ClipboardItem(
                imageData: data,
                width: width,
                height: height,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName
            )
            modelContext.insert(item)
        }

        saveAndEnforceLimit()
    }

    /// Add file URLs to the store
    func addFiles(urls: [URL], sourceAppBundleID: String? = nil, sourceAppName: String? = nil) {
        let content = urls.map { $0.path }.joined(separator: "\n")
        let hash = ClipboardItem.computeHash(content)

        if let existing = findByHash(hash) {
            // Update existing file item
            existing.createdAt = Date()
            existing.sourceAppBundleID = sourceAppBundleID
            existing.sourceAppName = sourceAppName
        } else {
            let item = ClipboardItem(
                fileURLs: urls,
                sourceAppBundleID: sourceAppBundleID,
                sourceAppName: sourceAppName
            )
            modelContext.insert(item)
        }

        saveAndEnforceLimit()
    }

    func delete(_ item: ClipboardItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    func clear() {
        let fetchDescriptor = FetchDescriptor<ClipboardItem>()
        if let items = try? modelContext.fetch(fetchDescriptor) {
            for item in items {
                modelContext.delete(item)
            }
        }
        try? modelContext.save()
    }

    func fetchAll() -> [ClipboardItem] {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = effectiveLimit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func findByHash(_ hash: String) -> ClipboardItem? {
        let predicate = #Predicate<ClipboardItem> { item in
            item.contentHash == hash
        }
        var descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func saveAndEnforceLimit() {
        do {
            try modelContext.save()
        } catch {
            print("[ClipboardStore] Failed to save: \(error.localizedDescription)")
            return
        }

        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let allItems = try? modelContext.fetch(descriptor) else { return }

        let limit = effectiveLimit
        if allItems.count > limit {
            let itemsToDelete = allItems.suffix(from: limit)
            for item in itemsToDelete {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }

    // MARK: - Storage Info

    /// Estimates total storage used by clipboard items (in bytes)
    func estimatedStorageSize() -> Int {
        let descriptor = FetchDescriptor<ClipboardItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return 0 }

        return items.reduce(0) { total, item in
            let imageSize = item.imageData?.count ?? 0
            return total + item.content.utf8.count + item.previewText.utf8.count + imageSize + 200 // 200 bytes overhead for metadata
        }
    }

    /// Returns the database file size on disk (in bytes)
    static func databaseFileSize() -> Int64 {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return 0
        }

        let dbPath = appSupport.appendingPathComponent("default.store")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath.path) else {
            return 0
        }

        return (attrs[.size] as? Int64) ?? 0
    }

    /// Formats bytes to human-readable string
    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
