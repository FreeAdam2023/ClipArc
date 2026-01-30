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
            Logger.debug("Saved previous app: \(previousApp?.localizedName ?? "none")")
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
        Logger.debug("Will restore focus to: \(appToRestore?.localizedName ?? "none")")

        // Close panel and release focus
        panel?.close()

        // Step 1: Deactivate our app first
        NSApp.deactivate()

        // Step 2: Schedule activation of previous app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let app = appToRestore, app.bundleIdentifier != Bundle.main.bundleIdentifier {
                Logger.debug("Activating app: \(app.localizedName ?? "unknown")")
                app.activate(options: .activateIgnoringOtherApps)
            }

            // Step 3: Wait for focus to fully transfer and keys to release, then paste
            // Use a longer delay (0.35s) to ensure the target app is fully active and ready to receive events
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                // Verify the target app is now frontmost
                let currentApp = NSWorkspace.shared.frontmostApplication
                Logger.debug("Current frontmost: \(currentApp?.localizedName ?? "unknown")")

                Logger.debug("Now pasting...")
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
                    PasteActionCoordinator.shared.performPaste(item: item)
                    self.hide(completion: nil)
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
                                    PasteActionCoordinator.shared.performPaste(item: item)
                                    onDismiss(nil)
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
                PasteActionCoordinator.shared.performPaste(item: item)
                onDismiss(nil)
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

// Note: CategoryTab, ClipboardCardView, FileThumbnailView, HorizontalEmptyStateView,
// UpgradePromptCard, VisualEffectView, and openSubscriptionWindow are in separate files:
// - ClipboardCardView.swift
// - FileThumbnailView.swift
// - PanelComponents.swift

// Note: Removed - ClipboardCardView, FileThumbnailView, CategoryTab, HorizontalEmptyStateView,
// UpgradePromptCard, VisualEffectView, and openSubscriptionWindow are now in separate files
