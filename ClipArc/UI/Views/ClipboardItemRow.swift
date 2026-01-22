//
//  ClipboardItemRow.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.type.icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .font(.system(.body, design: .default))
                    .lineLimit(2)
                    .truncationMode(.tail)

                HStack(spacing: 8) {
                    if let appName = item.sourceAppName {
                        Text(appName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.createdAt.relativeFormatted)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isSelected {
                Button(action: { onDelete?() }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

extension Date {
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    VStack {
        ClipboardItemRow(
            item: {
                let item = ClipboardItem(content: "Hello, World! This is a sample text that might be longer.", type: .text, sourceAppName: "Safari")
                return item
            }(),
            isSelected: true
        )
        ClipboardItemRow(
            item: {
                let item = ClipboardItem(content: "https://apple.com", type: .url, sourceAppName: "Chrome")
                return item
            }(),
            isSelected: false
        )
    }
    .padding()
    .frame(width: 450)
}
