//
//  SearchEngine.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import Foundation

enum SearchEngine {
    static func filter(items: [ClipboardItem], query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return items }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return items }

        var scoredItems: [(item: ClipboardItem, score: Int)] = []

        for item in items {
            let contentMatch = item.content.fuzzyMatch(trimmedQuery)
            let previewMatch = item.previewText.fuzzyMatch(trimmedQuery)

            if contentMatch.matches || previewMatch.matches {
                let score = max(contentMatch.score, previewMatch.score)
                scoredItems.append((item, score))
            }
        }

        return scoredItems
            .sorted { $0.score > $1.score }
            .map { $0.item }
    }

    static func simpleFilter(items: [ClipboardItem], query: String) -> [ClipboardItem] {
        guard !query.isEmpty else { return items }

        let lowercasedQuery = query.lowercased()

        return items.filter { item in
            item.content.lowercased().contains(lowercasedQuery) ||
            item.previewText.lowercased().contains(lowercasedQuery)
        }
    }
}
