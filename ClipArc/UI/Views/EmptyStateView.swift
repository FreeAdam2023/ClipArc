//
//  EmptyStateView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import SwiftUI

struct EmptyStateView: View {
    let hasSearchQuery: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasSearchQuery ? "magnifyingglass" : "clipboard")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(hasSearchQuery ? "No results found" : "Clipboard history is empty")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(hasSearchQuery
                 ? "Try a different search term"
                 : "Copy something to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    VStack {
        EmptyStateView(hasSearchQuery: false)
            .frame(height: 200)
        EmptyStateView(hasSearchQuery: true)
            .frame(height: 200)
    }
}
