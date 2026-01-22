//
//  String+FuzzyMatch.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import Foundation

extension String {
    func fuzzyMatch(_ query: String) -> (matches: Bool, score: Int) {
        guard !query.isEmpty else { return (true, 0) }

        let lowercasedSelf = self.lowercased()
        let lowercasedQuery = query.lowercased()

        if lowercasedSelf.contains(lowercasedQuery) {
            let lengthBonus = max(0, 100 - count)
            return (true, 100 + lengthBonus)
        }

        var queryIndex = lowercasedQuery.startIndex
        var selfIndex = lowercasedSelf.startIndex
        var score = 0
        var consecutiveMatches = 0

        while queryIndex < lowercasedQuery.endIndex && selfIndex < lowercasedSelf.endIndex {
            if lowercasedQuery[queryIndex] == lowercasedSelf[selfIndex] {
                score += 10 + consecutiveMatches * 5
                consecutiveMatches += 1
                queryIndex = lowercasedQuery.index(after: queryIndex)
            } else {
                consecutiveMatches = 0
            }
            selfIndex = lowercasedSelf.index(after: selfIndex)
        }

        let matches = queryIndex == lowercasedQuery.endIndex
        return (matches, matches ? score : 0)
    }
}
