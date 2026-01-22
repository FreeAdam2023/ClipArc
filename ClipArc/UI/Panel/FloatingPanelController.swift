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

    func hide() {
        appState.hidePanel()
        panel?.hideWithAnimation()
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

        let contentView = PanelContentView(appState: appState) { [weak self] in
            self?.hide()
        }
        .modelContainer(modelContainer)

        panel?.setContentView(contentView)
    }
}

struct PanelContentView: View {
    @Bindable var appState: AppState
    var onDismiss: () -> Void
    @State private var scrollPosition: ScrollPosition = .init(idType: UUID.self)

    var body: some View {
        HStack(spacing: 0) {
            // Search icon button on the left
            Button(action: {
                // TODO: Show search field
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, height: FloatingPanel.panelHeight)
            }
            .buttonStyle(.plain)

            if appState.filteredItems.isEmpty {
                HorizontalEmptyStateView()
            } else {
                // Horizontal scrolling cards
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(appState.filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardCardView(
                                item: item,
                                isSelected: index == appState.selectedIndex,
                                onSelect: {
                                    PasteService.pasteItem(item)
                                    onDismiss()
                                },
                                onDelete: {
                                    appState.deleteItem(item)
                                }
                            )
                            .id(item.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition($scrollPosition)
            }

            // Close button on the right
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, height: FloatingPanel.panelHeight)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onKeyPress(.escape) {
            onDismiss()
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
                PasteService.pasteItem(item)
                onDismiss()
            }
            return .handled
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

struct ClipboardCardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Type icon and time
                HStack {
                    Image(systemName: item.type.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(item.createdAt.shortRelativeFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if isHovered {
                        Button(action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Content preview
                Text(item.previewText)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, maxHeight: 60, alignment: .topLeading)

                // Source app
                if let appName = item.sourceAppName {
                    Text(appName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(width: 160, height: 130)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
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
