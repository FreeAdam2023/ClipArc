//
//  DirectPasteGuideView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-30.
//
//  Review-friendly guide for enabling Direct Paste
//  Key principles:
//  - Focus on "reducing repetitive steps", not "automation"
//  - User must manually add app in System Settings
//  - This is an optional enhancement, not a requirement

import SwiftUI

/// Main guide view for enabling Direct Paste feature
/// Uses review-friendly language focused on reducing repetitive interactions
struct DirectPasteGuideView: View {
    let onOpenSettings: () -> Void
    let onSkip: () -> Void
    let onDismiss: () -> Void

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(16)
            }

            Spacer().frame(height: 10)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
            }

            Spacer().frame(height: 20)

            // Title - Focus on benefit, not mechanism
            Text("Direct Paste")
                .font(.system(size: 28, weight: .bold))

            Spacer().frame(height: 8)

            // Subtitle - Emphasize reducing steps
            Text("Paste instantly to your active app\nwithout switching windows.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: 28)

            // Benefits card
            VStack(alignment: .leading, spacing: 14) {
                Text("What changes:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                BenefitItem(
                    icon: "cursorarrow.click.2",
                    text: "Click an item → content pastes immediately"
                )
                BenefitItem(
                    icon: "keyboard",
                    text: "No need to press ⌘V manually"
                )
                BenefitItem(
                    icon: "arrow.trianglehead.counterclockwise",
                    text: "Fewer steps, faster workflow"
                )
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.03))
            )
            .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            // Permission notice - Clear about manual process
            VStack(spacing: 6) {
                Text("This feature requires Accessibility permission.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text("You'll need to manually add ClipArc in System Settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            Spacer().frame(height: 24)

            // Primary action
            Button(action: {
                onOpenSettings()
            }) {
                Text("Open System Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)

            Spacer().frame(height: 12)

            // Secondary action
            Button(action: onSkip) {
                Text("Skip for Now")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 32)
        }
        .frame(width: 420, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
}

/// Friction guide bar shown at bottom of clipboard panel
/// Non-modal, subtle prompt based on detected friction
struct FrictionGuideBar: View {
    let onLearnHow: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reduce repetitive steps?")
                    .font(.system(size: 13, weight: .medium))
                Text("Paste directly without switching back.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Maybe Later") {
                FrictionDetector.shared.userDismissedGuide()
                onDismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            Button("Learn How") {
                FrictionDetector.shared.userAcceptedGuide()
                onLearnHow()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        )
    }
}

/// Benefit item row
private struct BenefitItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13))
        }
    }
}

// MARK: - Guide Window Controller

@MainActor
final class DirectPasteGuideController {
    static let shared = DirectPasteGuideController()

    private var guideWindow: NSWindow?

    func showGuide() {
        // Close existing if any
        guideWindow?.close()
        guideWindow = nil

        let guideView = DirectPasteGuideView(
            onOpenSettings: { [weak self] in
                DirectPasteCapabilityManager.shared.openAccessibilitySettings()
                self?.setupReturnObserver()
            },
            onSkip: { [weak self] in
                FrictionDetector.shared.userDismissedGuide()
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: guideView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 420, height: 580)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 580),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.center()

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        guideWindow = window
    }

    func dismiss() {
        guideWindow?.close()
        guideWindow = nil
        removeReturnObserver()
    }

    // MARK: - Return Observer

    private var returnObserver: NSObjectProtocol?

    private func setupReturnObserver() {
        removeReturnObserver()

        returnObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppReturn()
        }
    }

    private func removeReturnObserver() {
        if let observer = returnObserver {
            NotificationCenter.default.removeObserver(observer)
            returnObserver = nil
        }
    }

    private func handleAppReturn() {
        removeReturnObserver()

        // Check if permission was granted
        if DirectPasteCapabilityManager.shared.isAccessibilityGranted {
            // Success! Close guide
            dismiss()
            Logger.debug("Direct Paste permission granted!")
        }
        // If not granted, guide stays open for user to try again
    }

    private init() {
        // Listen for friction guide notification
        NotificationCenter.default.addObserver(
            forName: .showFrictionGuide,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showGuide()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .showDirectPasteGuide,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showGuide()
            }
        }
    }
}

#Preview("Direct Paste Guide") {
    DirectPasteGuideView(
        onOpenSettings: {},
        onSkip: {},
        onDismiss: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}

#Preview("Friction Guide Bar") {
    FrictionGuideBar(
        onLearnHow: {},
        onDismiss: {}
    )
    .padding(20)
    .frame(width: 450)
}
