//
//  PasteActionCoordinator.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-30.
//

import AppKit
import SwiftUI

/// Notification posted when friction guide should be shown
extension Notification.Name {
    static let showFrictionGuide = Notification.Name("showFrictionGuide")
    static let showDirectPasteGuide = Notification.Name("showDirectPasteGuide")
    static let showScreenshotMonitorPrompt = Notification.Name("showScreenshotMonitorPrompt")
}

/// Coordinates the complete paste flow
/// Orchestrates between PasteService, CapabilityManager, and FrictionDetector
@MainActor
final class PasteActionCoordinator {
    static let shared = PasteActionCoordinator()

    private let capabilityManager = DirectPasteCapabilityManager.shared
    private let frictionDetector = FrictionDetector.shared

    // MARK: - Toast Management

    private var toastWindow: NSWindow?
    private var dismissWorkItem: DispatchWorkItem?

    // MARK: - Public API

    /// Perform paste action (called from UI)
    /// This is the main entry point for all paste operations
    func performPaste(item: ClipboardItem, asPlainText: Bool = false) {
        // 1. Always copy to clipboard first
        PasteService.copyItem(item, asPlainText: asPlainText)

        // 2. Track behavior for friction detection
        frictionDetector.trackClick(itemID: item.id)

        // 3. Track action for app rating
        AppRatingManager.shared.trackAction()

        // 4. Decide behavior based on capability state
        if capabilityManager.canDirectPaste {
            // Enhanced Mode: Auto Cmd+V
            performDirectPaste()
        } else {
            // Normal Mode: Show toast
            showCopiedToast()

            // Check if we should show friction guide
            if frictionDetector.shouldShowFrictionGuide {
                // Delay slightly to not interrupt the copy feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showFrictionGuide()
                }
            }
        }
    }

    /// Perform copy only (no paste attempt)
    func performCopyOnly(item: ClipboardItem, asPlainText: Bool = false) {
        PasteService.copyItem(item, asPlainText: asPlainText)
        showCopiedToast()
    }

    // MARK: - Private Methods

    private func performDirectPaste() {
        // Small delay to ensure focus has transferred to target app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            PasteService.simulateCmdV()
        }
    }

    private func showFrictionGuide() {
        frictionDetector.markGuideShown()
        NotificationCenter.default.post(name: .showFrictionGuide, object: nil)
    }

    // MARK: - Toast UI

    private func showCopiedToast() {
        // Cancel any pending dismiss
        dismissWorkItem?.cancel()
        dismissWorkItem = nil

        // Close existing toast if any
        toastWindow?.orderOut(nil)
        toastWindow?.close()
        toastWindow = nil

        let toastView = CopiedToastView(
            onDismiss: { [weak self] in
                self?.dismissToast()
            }
        )

        let hostingView = NSHostingView(rootView: toastView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 160, height: 100)

        let window = ToastPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = false
        window.hidesOnDeactivate = false  // Keep visible when app loses focus
        window.center()

        window.orderFrontRegardless()

        toastWindow = window

        // Auto-dismiss after 1.5 seconds (reduced from 2s for snappier UX)
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissToast()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)

        Logger.debug("Copied toast displayed")
    }

    private func dismissToast() {
        guard let window = toastWindow else { return }
        toastWindow = nil  // Clear reference first to prevent multiple dismissals

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            window.close()
        })
    }

    // MARK: - Private Init

    private init() {}
}

// MARK: - Toast Panel Class

private class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Copied Toast View

struct CopiedToastView: View {
    let onDismiss: () -> Void

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.green)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0)
            }

            Text(L10n.Clipboard.copied)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)

            Text(L10n.Paste.pressToManualPaste)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
        .onTapGesture {
            onDismiss()
        }
    }
}
