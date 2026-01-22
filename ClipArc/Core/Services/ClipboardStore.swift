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
    private let historyLimit: Int

    init(modelContext: ModelContext, historyLimit: Int = 100) {
        self.modelContext = modelContext
        self.historyLimit = historyLimit
    }

    func add(content: String, type: ClipboardItemType, sourceAppBundleID: String? = nil, sourceAppName: String? = nil) {
        let hash = ClipboardItem.computeHash(content)

        if let existing = findByHash(hash) {
            existing.createdAt = Date()
            existing.sourceAppBundleID = sourceAppBundleID
            existing.sourceAppName = sourceAppName
        } else {
            let item = ClipboardItem(
                content: content,
                type: type,
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
        descriptor.fetchLimit = historyLimit
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
        try? modelContext.save()

        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let allItems = try? modelContext.fetch(descriptor) else { return }

        if allItems.count > historyLimit {
            let itemsToDelete = allItems.suffix(from: historyLimit)
            for item in itemsToDelete {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }
}
