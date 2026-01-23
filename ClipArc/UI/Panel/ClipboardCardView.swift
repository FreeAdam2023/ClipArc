//
//  ClipboardCardView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-23.
//

import AppKit
import SwiftUI
import QuickLookThumbnailing

struct ClipboardCardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let isItemSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onToggleSelection: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool { colorScheme == .dark }

    private var selectedGlow: Color {
        item.type.accentColor.opacity(isDarkMode ? 0.6 : 0.4)
    }

    var body: some View {
        Button(action: {
            if isSelectionMode {
                onToggleSelection()
            } else {
                onSelect()
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader
                contentPreview
                    .padding(.horizontal, UIConstants.cardHorizontalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                cardFooter
            }
            .frame(width: UIConstants.cardWidth, height: UIConstants.cardHeight)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(color: isSelected ? selectedGlow : .clear, radius: isSelected ? 12 : 0, y: 0)
            .shadow(color: .black.opacity(isDarkMode ? 0.3 : 0.1), radius: isHovered ? 12 : 6, y: isHovered ? 6 : 3)
            .overlay(alignment: .topLeading) { selectionCheckbox }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: TimingConstants.mediumAnimationDuration)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.02 : 1.0))
        .animation(.spring(response: TimingConstants.longAnimationDuration, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: TimingConstants.longAnimationDuration, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: TimingConstants.longAnimationDuration, dampingFraction: 0.7), value: isItemSelected)
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: UIConstants.smallCornerRadius)
                    .fill(item.type.accentColor.opacity(isDarkMode ? 0.3 : 0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: item.type.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.type.accentColor)
            }

            Text(item.type.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(item.type.accentColor)

            Spacer()

            Text(item.createdAt.shortRelativeFormatted)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if isHovered || isSelected {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.3))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, UIConstants.cardHorizontalPadding)
        .padding(.top, UIConstants.cardVerticalPadding)
        .padding(.bottom, 10)
    }

    // MARK: - Card Footer

    private var cardFooter: some View {
        HStack(spacing: 4) {
            if let appName = item.sourceAppName {
                Image(systemName: "app.fill")
                    .font(.system(size: 9))
                Text(appName)
                    .lineLimit(1)
            }
            Spacer()

            if isSelected && !isSelectionMode {
                HStack(spacing: 3) {
                    Image(systemName: "return")
                        .font(.system(size: 9))
                    Text("Enter")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(item.type.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(item.type.accentColor.opacity(0.15)))
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, UIConstants.cardHorizontalPadding)
        .padding(.bottom, UIConstants.cardVerticalPadding)
        .padding(.top, 8)
    }

    // MARK: - Background & Border

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            item.type.accentColor.opacity(isSelected ? 0.15 : 0.08),
                            item.type.accentColor.opacity(isSelected ? 0.08 : 0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if isSelected {
                RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius)
                    .fill(item.type.accentColor.opacity(isDarkMode ? 0.1 : 0.05))
            }
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: UIConstants.cardCornerRadius)
            .stroke(
                isSelected ? item.type.accentColor : (isHovered ? Color.primary.opacity(0.15) : Color.primary.opacity(0.05)),
                lineWidth: isSelected ? UIConstants.selectedBorderWidth : 1
            )
    }

    // MARK: - Selection Checkbox

    @ViewBuilder
    private var selectionCheckbox: some View {
        if isSelectionMode {
            ZStack {
                Circle()
                    .fill(isItemSelected ? Color.blue : (isDarkMode ? Color.black.opacity(0.6) : Color.white.opacity(0.95)))
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

                if isItemSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            }
            .offset(x: -6, y: -6)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .url:
            URLContentPreview(item: item, isDarkMode: isDarkMode)
        case .code:
            CodeContentPreview(item: item, isDarkMode: isDarkMode)
        case .color:
            ColorContentPreview(item: item)
        case .file:
            FileContentPreview(item: item)
        case .image:
            ImageContentPreview(item: item)
        default:
            TextContentPreview(item: item)
        }
    }
}

// MARK: - Content Preview Components

private struct URLContentPreview: View {
    let item: ClipboardItem
    let isDarkMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = URL(string: item.content) {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: UIConstants.smallCornerRadius)
                            .fill(Color.blue.opacity(isDarkMode ? 0.3 : 0.1))
                            .frame(width: 28, height: 28)
                        Image(systemName: "link")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.blue)
                    }

                    Text(url.host ?? "")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }

                if let title = item.urlTitle {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }

                Spacer()

                Text(item.content)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: UIConstants.smallCornerRadius)
                            .fill(Color.primary.opacity(isDarkMode ? 0.1 : 0.04))
                    )
            }
        }
    }
}

private struct CodeContentPreview: View {
    let item: ClipboardItem
    let isDarkMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(.red.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(.yellow.opacity(0.8)).frame(width: 8, height: 8)
                Circle().fill(.green.opacity(0.8)).frame(width: 8, height: 8)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Text(item.previewText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(isDarkMode ? .green.opacity(0.9) : .primary)
                .lineLimit(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: UIConstants.mediumCornerRadius)
                .fill(isDarkMode ? Color.black.opacity(0.4) : Color.black.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.mediumCornerRadius)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct ColorContentPreview: View {
    let item: ClipboardItem

    var body: some View {
        VStack(spacing: 12) {
            if let color = parseColor(item.content) {
                RoundedRectangle(cornerRadius: UIConstants.largeCornerRadius)
                    .fill(color)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.largeCornerRadius)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.4), radius: 8, y: 4)
            }

            Text(item.content.uppercased())
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private func parseColor(_ string: String) -> Color? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            var hex = String(trimmed.dropFirst())
            if hex.count == 3 {
                hex = hex.map { "\($0)\($0)" }.joined()
            }
            if hex.count == 6, let int = UInt64(hex, radix: 16) {
                let r = Double((int >> 16) & 0xFF) / 255.0
                let g = Double((int >> 8) & 0xFF) / 255.0
                let b = Double(int & 0xFF) / 255.0
                return Color(red: r, green: g, blue: b)
            }
        }
        return nil
    }
}

private struct FileContentPreview: View {
    let item: ClipboardItem

    var body: some View {
        let urls = item.fileURLs
        if urls.count == 1 {
            FileThumbnailView(
                item: item,
                fileURL: urls[0],
                accentColor: item.type.accentColor,
                fileIconName: fileIcon(for: urls[0].path)
            )
        } else if urls.count > 1 {
            MultipleFilesPreview(item: item, urls: urls)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(item.type.accentColor)
                Text(item.previewText)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
        }
    }

    private func fileIcon(for path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "doc", "docx": return "doc.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "rectangle.split.3x1.fill"
        case "zip", "rar", "7z": return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tiff", "bmp": return "photo.fill"
        case "mp4", "mov", "avi": return "video.fill"
        case "mp3", "wav", "m4a": return "music.note"
        default: return "doc.fill"
        }
    }
}

private struct MultipleFilesPreview: View {
    let item: ClipboardItem
    let urls: [URL]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(item.type.accentColor)
                Text("\(urls.count) files")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            ForEach(urls.prefix(3), id: \.self) { url in
                HStack(spacing: 4) {
                    Image(systemName: fileIcon(for: url.path))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(url.lastPathComponent)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if urls.count > 3 {
                Text("... and \(urls.count - 3) more")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func fileIcon(for path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "doc", "docx": return "doc.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "rectangle.split.3x1.fill"
        case "zip", "rar", "7z": return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tiff", "bmp": return "photo.fill"
        case "mp4", "mov", "avi": return "video.fill"
        case "mp3", "wav", "m4a": return "music.note"
        default: return "doc.fill"
        }
    }
}

private struct ImageContentPreview: View {
    let item: ClipboardItem

    var body: some View {
        if let imageData = item.imageData,
           let nsImage = NSImage(data: imageData) {
            let aspectRatio = CGFloat(item.imageWidth) / max(CGFloat(item.imageHeight), 1)

            VStack(spacing: 6) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxWidth: UIConstants.imagePreviewMaxWidth, maxHeight: UIConstants.imagePreviewMaxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: UIConstants.mediumCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.mediumCornerRadius)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                Text("\(item.imageWidth) x \(item.imageHeight)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.purple.opacity(0.6))
                Text(item.previewText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TextContentPreview: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.previewText)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(7)
                .multilineTextAlignment(.leading)

            Spacer()

            HStack {
                Spacer()
                Text("\(item.content.count) chars")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
