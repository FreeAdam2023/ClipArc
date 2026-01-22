//
//  FloatingPanelController.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import SwiftUI
import SwiftData

@MainActor
final class FloatingPanelController {
    private var panel: FloatingPanel?
    private let appState: AppState
    private let modelContainer: ModelContainer

    init(appState: AppState, modelContainer: ModelContainer) {
        self.appState = appState
        self.modelContainer = modelContainer
    }

    func show() {
        if panel == nil {
            createPanel()
        }

        appState.showPanel()
        panel?.showAtBottom()
    }

    func hide(completion: (() -> Void)? = nil) {
        appState.hidePanel()
        panel?.hideWithAnimation(completion: completion)
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private func createPanel() {
        let screen = FloatingPanel.targetScreen()
        let screenFrame = screen.frame
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: screenFrame.width, height: FloatingPanel.panelHeight))

        let contentView = PanelContentView(appState: appState) { [weak self] completion in
            self?.hide(completion: completion)
        }
        .modelContainer(modelContainer)

        panel?.setContentView(contentView)
    }
}

struct PanelContentView: View {
    @Bindable var appState: AppState
    var onDismiss: ((() -> Void)?) -> Void  // Now accepts an optional completion handler
    @State private var scrollPosition: ScrollPosition = .init(idType: UUID.self)
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with search and filters
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()
                .opacity(0.5)

            // Cards area
            if appState.filteredItems.isEmpty {
                HorizontalEmptyStateView()
            } else {
                // Waterfall-style horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(Array(appState.filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardCardView(
                                item: item,
                                isSelected: index == appState.selectedIndex,
                                isSelectionMode: appState.isSelectionMode,
                                isItemSelected: appState.selectedItemIDs.contains(item.id),
                                onSelect: {
                                    print("[FloatingPanel] Card clicked - item: \(item.previewText.prefix(30))")
                                    appState.touchItem(item)  // Move to front
                                    PasteService.copyItem(item)  // Copy first
                                    onDismiss {
                                        // Small delay to let system restore focus, then paste
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                            PasteService.simulatePaste()
                                        }
                                    }
                                },
                                onDelete: {
                                    appState.deleteItem(item)
                                },
                                onToggleSelection: {
                                    appState.toggleItemSelection(item)
                                }
                            )
                            .id(item.id)
                            .scrollTransition(.animated(.easeInOut)) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0.85)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
                            }
                        }

                        // Upgrade prompt card for free users
                        if !appState.isProUser {
                            UpgradePromptCard(
                                itemCount: appState.items.count,
                                limit: AppState.freeHistoryLimit,
                                onUpgrade: {
                                    openSubscriptionWindow(appState: appState)
                                }
                            )
                            .scrollTransition(.animated(.easeInOut)) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0.85)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.95)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 12)
                }
                .contentMargins(.horizontal, 24, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .automatic))
                .scrollPosition($scrollPosition)
                .scrollClipDisabled()
                .scrollBounceBehavior(.automatic)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onKeyPress(.escape) {
            onDismiss(nil)
            return .handled
        }
        .onKeyPress(.leftArrow) {
            appState.moveSelectionUp()
            scrollToSelected()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            appState.moveSelectionDown()
            scrollToSelected()
            return .handled
        }
        .onKeyPress(.return) {
            if let item = appState.selectedItem {
                appState.touchItem(item)  // Move to front
                PasteService.copyItem(item)  // Copy first
                onDismiss {
                    // Small delay to let system restore focus, then paste
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        PasteService.simulatePaste()
                    }
                }
            }
            return .handled
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                TextField(L10n.Clipboard.searchPlaceholder, text: $appState.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFocused)

                if !appState.searchQuery.isEmpty {
                    Button(action: { appState.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.06))
            )
            .frame(width: 200)

            // Category filter tabs
            categoryTabs

            Spacer()

            // Usage indicator for free users
            if !appState.isProUser {
                usageBadge
            }

            // Selection mode controls
            if appState.isSelectionMode {
                // Select All button
                Button(action: {
                    appState.selectAllItems()
                }) {
                    Text(L10n.selectAll)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                // Delete Selected button
                if appState.selectedCount > 0 {
                    Button(action: {
                        appState.deleteSelectedItems()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("\(L10n.Clipboard.deleteSelected) (\(appState.selectedCount))")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.red))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Edit/Done button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.toggleSelectionMode()
                }
            }) {
                Text(appState.isSelectionMode ? L10n.done : L10n.edit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(appState.isSelectionMode ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            // Close button
            Button(action: { onDismiss(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Usage Badge

    private var usageBadge: some View {
        let count = appState.items.count
        let limit = AppState.freeHistoryLimit
        let isAtLimit = count >= limit

        return HStack(spacing: 4) {
            Image(systemName: isAtLimit ? "exclamationmark.circle.fill" : "doc.on.clipboard")
                .font(.system(size: 10))
            Text("\(min(count, limit))/\(limit)")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(isAtLimit ? .orange : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isAtLimit ? Color.orange.opacity(0.15) : Color.primary.opacity(0.06))
        )
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "All" tab
                CategoryTab(
                    title: L10n.Clipboard.typeAll,
                    icon: "square.grid.2x2",
                    isSelected: appState.selectedType == nil && !appState.showFrequentOnly,
                    color: .primary
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.selectedType = nil
                        appState.showFrequentOnly = false
                        appState.selectedIndex = 0
                    }
                }

                // "Frequent" tab - only show if there are frequent items
                if appState.hasFrequentItems {
                    CategoryTab(
                        title: L10n.Clipboard.typeFrequent,
                        icon: "star.fill",
                        isSelected: appState.showFrequentOnly,
                        color: .orange
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.showFrequentOnly = true
                            appState.selectedType = nil
                            appState.selectedIndex = 0
                        }
                    }
                }

                // Type-specific tabs
                ForEach(appState.availableTypes, id: \.self) { type in
                    CategoryTab(
                        title: type.displayName,
                        icon: type.icon,
                        isSelected: appState.selectedType == type && !appState.showFrequentOnly,
                        color: type.accentColor
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.selectedType = type
                            appState.showFrequentOnly = false
                            appState.selectedIndex = 0
                        }
                    }
                }
            }
        }
    }

    private func scrollToSelected() {
        if let item = appState.selectedItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollPosition.scrollTo(id: item.id)
            }
        }
    }
}

// MARK: - Category Tab

struct CategoryTab: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? .white : (isHovered ? color : .secondary))
            .background(
                Capsule()
                    .fill(isSelected ? color : (isHovered ? color.opacity(0.15) : Color.primary.opacity(0.06)))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct ClipboardCardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let isItemSelected: Bool  // Whether this item is selected in batch selection
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onToggleSelection: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            if isSelectionMode {
                onToggleSelection()
            } else {
                onSelect()
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Top color bar with type indicator
                HStack(spacing: 6) {
                    // Type icon with colored background
                    ZStack {
                        Circle()
                            .fill(item.type.accentColor.opacity(0.2))
                            .frame(width: 24, height: 24)

                        Image(systemName: item.type.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(item.type.accentColor)
                    }

                    Text(item.type.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(item.type.accentColor)

                    Spacer()

                    Text(item.createdAt.shortRelativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if isHovered {
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)

                // Content area
                contentPreview
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // Source app footer
                HStack(spacing: 4) {
                    if let appName = item.sourceAppName {
                        Image(systemName: "app.fill")
                            .font(.system(size: 8))
                        Text(appName)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .padding(.top, 6)
            }
            .frame(width: 200, height: 180)
            .background(
                ZStack {
                    // Base background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)

                    // Gradient overlay based on type
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: isSelected ? [item.type.accentColor.opacity(0.15), item.type.accentColor.opacity(0.05)] : item.type.gradientColors.map { $0.opacity(0.5) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? item.type.accentColor : (isHovered ? Color.primary.opacity(0.1) : Color.clear),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
            .overlay(alignment: .topLeading) {
                if isSelectionMode {
                    ZStack {
                        Circle()
                            .fill(isItemSelected ? Color.blue : Color.white.opacity(0.9))
                            .frame(width: 24, height: 24)
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                        if isItemSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Circle()
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .offset(x: -4, y: -4)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isItemSelected)
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .url:
            VStack(alignment: .leading, spacing: 4) {
                if let url = URL(string: item.content) {
                    // Page title (if available) - most prominent
                    if let title = item.urlTitle {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    // Domain with icon
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)

                        Text(url.host ?? "")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(item.urlTitle != nil ? .secondary : .primary)
                            .lineLimit(1)
                    }

                    // Path (only show if no title, to save space)
                    if item.urlTitle == nil, let path = url.path.isEmpty ? nil : url.path, path != "/" {
                        Text(path)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Full URL (truncated)
                    Text(item.content)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(item.urlTitle != nil ? 1 : 2)
                        .padding(.top, 2)
                }
            }

        case .code:
            Text(item.previewText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.05))
                )

        case .color:
            HStack(spacing: 8) {
                if let color = parseColor(item.content) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
                Text(item.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
            }

        case .file:
            let urls = item.fileURLs
            if urls.count == 1 {
                // Single file - check if it's an image for thumbnail
                let fileURL = urls[0]
                if isImageFile(fileURL), let thumbnail = loadThumbnail(for: fileURL) {
                    // Image file with thumbnail
                    VStack(spacing: 4) {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 180, maxHeight: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )

                        Text(fileURL.lastPathComponent)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(fileURL.deletingLastPathComponent().path)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                } else {
                    // Non-image file or failed to load thumbnail
                    HStack(spacing: 8) {
                        Image(systemName: fileIcon(for: fileURL.path))
                            .font(.system(size: 24))
                            .foregroundStyle(item.type.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(fileURL.lastPathComponent)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Text(fileURL.deletingLastPathComponent().path)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            } else if urls.count > 1 {
                // Multiple files
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(item.type.accentColor)

                        Text("\(urls.count) files")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    // Show first few file names
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
            } else {
                // Fallback to text display
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

        case .image:
            // Image preview
            if let imageData = item.imageData,
               let nsImage = NSImage(data: imageData) {
                VStack(spacing: 4) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 180, maxHeight: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    // Image dimensions
                    Text("\(item.imageWidth) × \(item.imageHeight)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else {
                // Fallback if image data is not available
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.purple.opacity(0.6))
                    Text(item.previewText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

        default:
            Text(item.previewText)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(5)
                .multilineTextAlignment(.leading)
        }
    }

    private func parseColor(_ string: String) -> Color? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse hex color
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

    /// Check if a file is an image based on extension
    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp", "ico", "icns"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    /// Load a thumbnail for an image file
    private func loadThumbnail(for url: URL) -> NSImage? {
        // Check if file exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        // Try to load the image
        guard let image = NSImage(contentsOf: url) else { return nil }

        // Create a thumbnail (max 180x90 for card display)
        let maxSize = CGSize(width: 180, height: 90)
        let originalSize = image.size

        // Calculate scaled size maintaining aspect ratio
        let widthRatio = maxSize.width / originalSize.width
        let heightRatio = maxSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio, 1.0)  // Don't upscale

        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        // Create thumbnail
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()

        return thumbnail
    }
}

struct HorizontalEmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text(L10n.Clipboard.emptyTitle)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L10n.Clipboard.emptySubtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Upgrade Prompt Card

struct UpgradePromptCard: View {
    let itemCount: Int
    let limit: Int
    let onUpgrade: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onUpgrade) {
            VStack(spacing: 8) {
                // Crown icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Message
                VStack(spacing: 2) {
                    Text(L10n.Onboarding.subscriptionTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(L10n.Onboarding.freeVsPro)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Upgrade button
                Text(L10n.Settings.upgradeToPro)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .frame(width: 200, height: 180)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.08), Color.yellow.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: isHovered ? [.orange.opacity(0.5), .yellow.opacity(0.3)] : [.clear, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - Subscription Window Helper

@MainActor
func openSubscriptionWindow(appState: AppState) {
    let subscriptionView = SubscriptionView(subscriptionManager: appState.subscriptionManager)

    let hostingView = NSHostingView(rootView: subscriptionView)
    hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 500)

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
        styleMask: [.titled, .closable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )

    window.contentView = hostingView
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isMovableByWindowBackground = true
    window.center()
    window.makeKeyAndOrderFront(nil)

    // Keep a reference to prevent deallocation
    NSApp.activate(ignoringOtherApps: true)
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
