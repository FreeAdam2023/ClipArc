//
//  FloatingPanelController.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import SwiftUI
import SwiftData
import QuickLookThumbnailing

@MainActor
final class FloatingPanelController {
    private var panel: FloatingPanel?
    private let appState: AppState
    private let modelContainer: ModelContainer
    private var keyboardMonitor: Any?
    private var previousApp: NSRunningApplication?  // Remember the app that was active before showing panel

    init(appState: AppState, modelContainer: ModelContainer) {
        self.appState = appState
        self.modelContainer = modelContainer
    }

    func show() {
        // Remember the currently active app before showing panel
        // Must capture this BEFORE we activate our app
        let frontApp = NSWorkspace.shared.frontmostApplication
        if frontApp?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontApp
            print("[FloatingPanel] Saved previous app: \(previousApp?.localizedName ?? "none")")
        }

        // Always recreate panel to ensure clean state
        createPanel()

        appState.showPanel()
        panel?.showAtBottom()
        setupKeyboardMonitor()
    }

    func hide(completion: (() -> Void)? = nil) {
        removeKeyboardMonitor()
        appState.hidePanel()

        let appToRestore = previousApp
        print("[FloatingPanel] Will restore focus to: \(appToRestore?.localizedName ?? "none")")

        // Close panel and release focus
        panel?.close()

        // Step 1: Deactivate our app first
        NSApp.deactivate()

        // Step 2: Schedule activation of previous app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let app = appToRestore, app.bundleIdentifier != Bundle.main.bundleIdentifier {
                print("[FloatingPanel] Activating app: \(app.localizedName ?? "unknown")")
                app.activate(options: .activateIgnoringOtherApps)
            }

            // Step 3: Wait for focus to fully transfer and keys to release, then paste
            // Use a longer delay (0.35s) to ensure the target app is fully active and ready to receive events
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                // Verify the target app is now frontmost
                let currentApp = NSWorkspace.shared.frontmostApplication
                print("[FloatingPanel] Current frontmost: \(currentApp?.localizedName ?? "unknown")")

                print("[FloatingPanel] Now pasting...")
                completion?()
            }
        }
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

    private func setupKeyboardMonitor() {
        removeKeyboardMonitor()

        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            switch Int(event.keyCode) {
            case 123: // Left arrow
                self.appState.moveSelectionUp()
                return nil // Consume event

            case 124: // Right arrow
                self.appState.moveSelectionDown()
                return nil

            case 53: // Escape
                self.hide()
                return nil

            case 36: // Return/Enter
                if let item = self.appState.selectedItem {
                    self.appState.touchItem(item)
                    PasteService.copyItem(item)
                    self.hide {
                        // Focus should be restored by hide(), now paste
                        PasteService.simulatePaste()
                    }
                }
                return nil

            default:
                return event
            }
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
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
                                    appState.touchItem(item)  // Move to front
                                    PasteService.copyItem(item)  // Copy first
                                    onDismiss {
                                        // Focus restored by hide(), now paste
                                        PasteService.simulatePaste()
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
                    // Focus restored by hide(), now paste
                    PasteService.simulatePaste()
                }
            }
            return .handled
        }
        .onChange(of: appState.scrollToSelectedTrigger) {
            scrollToSelected()
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
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool { colorScheme == .dark }

    // Dynamic colors based on color scheme
    private var cardBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(.regularMaterial)
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

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
                // Top bar with type indicator
                HStack(spacing: 8) {
                    // Type icon with colored background
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
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
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 10)

                // Content area
                contentPreview
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // Source app footer
                HStack(spacing: 4) {
                    if let appName = item.sourceAppName {
                        Image(systemName: "app.fill")
                            .font(.system(size: 9))
                        Text(appName)
                            .lineLimit(1)
                    }
                    Spacer()

                    // Selection indicator when selected via keyboard
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
                        .background(
                            Capsule()
                                .fill(item.type.accentColor.opacity(0.15))
                        )
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 8)
            }
            .frame(width: 260, height: 240)
            .background(
                ZStack {
                    // Base background with material
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)

                    // Colored gradient overlay
                    RoundedRectangle(cornerRadius: 16)
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

                    // Selection highlight overlay
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(item.type.accentColor.opacity(isDarkMode ? 0.1 : 0.05))
                    }
                }
            )
            // Selection border with glow effect
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? item.type.accentColor : (isHovered ? Color.primary.opacity(0.15) : Color.primary.opacity(0.05)),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            // Glow effect for selected card
            .shadow(
                color: isSelected ? selectedGlow : .clear,
                radius: isSelected ? 12 : 0,
                y: 0
            )
            // Regular shadow
            .shadow(
                color: .black.opacity(isDarkMode ? 0.3 : 0.1),
                radius: isHovered ? 12 : 6,
                y: isHovered ? 6 : 3
            )
            // Selection mode checkbox
            .overlay(alignment: .topLeading) {
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
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isSelected ? 1.02 : (isHovered ? 1.02 : 1.0))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSelected)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isItemSelected)
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .url:
            VStack(alignment: .leading, spacing: 8) {
                if let url = URL(string: item.content) {
                    // Domain badge
                    HStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
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

                    // Page title (if available)
                    if let title = item.urlTitle {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }

                    Spacer()

                    // Full URL at bottom
                    Text(item.content)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(isDarkMode ? 0.1 : 0.04))
                        )
                }
            }

        case .code:
            VStack(alignment: .leading, spacing: 0) {
                // Code header
                HStack(spacing: 6) {
                    Circle().fill(.red.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(.yellow.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(.green.opacity(0.8)).frame(width: 8, height: 8)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                // Code content
                Text(item.previewText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isDarkMode ? .green.opacity(0.9) : .primary)
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDarkMode ? Color.black.opacity(0.4) : Color.black.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

        case .color:
            VStack(spacing: 12) {
                if let color = parseColor(item.content) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: color.opacity(0.4), radius: 8, y: 4)
                }

                Text(item.content.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

        case .file:
            let urls = item.fileURLs
            if urls.count == 1 {
                // Single file - try to show thumbnail
                let fileURL = urls[0]
                FileThumbnailView(
                    item: item,
                    fileURL: fileURL,
                    accentColor: item.type.accentColor,
                    fileIconName: fileIcon(for: fileURL.path)
                )
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
            // Image preview - preserve aspect ratio
            if let imageData = item.imageData,
               let nsImage = NSImage(data: imageData) {
                let aspectRatio = CGFloat(item.imageWidth) / max(CGFloat(item.imageHeight), 1)

                VStack(spacing: 6) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .frame(maxWidth: 220, maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                    // Image dimensions
                    Text("\(item.imageWidth) × \(item.imageHeight)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else {
                // Fallback if image data is not available
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple.opacity(0.6))
                    Text(item.previewText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

        default:
            // Plain text with nice styling
            VStack(alignment: .leading, spacing: 8) {
                Text(item.previewText)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(7)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Character count
                HStack {
                    Spacer()
                    Text("\(item.content.count) chars")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
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
        let maxSize = CGSize(width: 220, height: 130)
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

// MARK: - File Thumbnail View

struct FileThumbnailView: View {
    let item: ClipboardItem  // Need item to cache thumbnail
    let fileURL: URL
    let accentColor: Color
    let fileIconName: String

    @State private var thumbnail: NSImage?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 6) {
            if let thumbnail = thumbnail {
                // Show thumbnail - preserve aspect ratio
                let imageSize = thumbnail.size
                let aspectRatio = imageSize.width / max(imageSize.height, 1)

                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxWidth: 220, maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            } else if isLoading {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 100, height: 80)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            } else {
                // Fallback to icon
                Image(systemName: fileIconName)
                    .font(.system(size: 40))
                    .foregroundStyle(accentColor)
                    .frame(height: 80)
            }

            Text(fileURL.lastPathComponent)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(fileURL.deletingLastPathComponent().path)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // First check for cached thumbnail
        if let cachedData = item.fileThumbnailData,
           let cachedImage = NSImage(data: cachedData) {
            await MainActor.run {
                self.thumbnail = cachedImage
                self.isLoading = false
            }
            return
        }

        // Try to generate thumbnail (only works if we have file access)
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }

        // Use Quick Look to generate thumbnail
        let size = CGSize(width: 220, height: 130)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let image = representation.nsImage

            // Cache the thumbnail
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                await MainActor.run {
                    item.fileThumbnailData = pngData
                }
            }

            await MainActor.run {
                self.thumbnail = image
                self.isLoading = false
            }
        } catch {
            // Quick Look failed, try direct image loading for image files
            if isImageFile(fileURL), let image = NSImage(contentsOf: fileURL) {
                let scaledImage = createScaledThumbnail(from: image, maxSize: size)

                // Cache the thumbnail
                if let tiffData = scaledImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    await MainActor.run {
                        item.fileThumbnailData = pngData
                    }
                }

                await MainActor.run {
                    self.thumbnail = scaledImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp", "ico", "icns"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    private func createScaledThumbnail(from image: NSImage, maxSize: CGSize) -> NSImage {
        let originalSize = image.size
        let widthRatio = maxSize.width / originalSize.width
        let heightRatio = maxSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio, 1.0)

        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

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
            .frame(width: 260, height: 240)
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
    // Open Settings window (Subscription tab is in Settings)
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
