//
//  ClipboardListView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import SwiftUI

struct ClipboardListView: View {
    let items: [ClipboardItem]
    @Binding var selectedIndex: Int
    var onSelect: (ClipboardItem) -> Void
    var onDelete: (ClipboardItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            isSelected: index == selectedIndex,
                            onDelete: { onDelete(item) }
                        )
                        .id(index)
                        .onTapGesture {
                            selectedIndex = index
                            onSelect(item)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onChange(of: selectedIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

#Preview {
    ClipboardListView(
        items: [
            ClipboardItem(content: "First item", type: .text, sourceAppName: "Safari"),
            ClipboardItem(content: "https://google.com", type: .url, sourceAppName: "Chrome"),
            ClipboardItem(content: "Another piece of text that is longer", type: .text, sourceAppName: "Notes"),
        ],
        selectedIndex: .constant(0),
        onSelect: { _ in },
        onDelete: { _ in }
    )
    .frame(width: 450, height: 300)
}
