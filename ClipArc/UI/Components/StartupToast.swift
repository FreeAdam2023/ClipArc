//
//  StartupToast.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-22.
//

import AppKit
import SwiftUI

@MainActor
final class StartupToastController {
    private var window: NSWindow?

    func show() {
        let toastView = StartupToastView()
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 72)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 72),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.hasShadow = true
        window.ignoresMouseEvents = true

        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 140
            let y = screenFrame.maxY - 100
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.window = window

        // Animate in (use orderFront since toast doesn't need key window status)
        window.alphaValue = 0
        window.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }

        // Auto dismiss after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.dismiss()
        }
    }

    private func dismiss() {
        guard let window = window else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [weak self] in
                self?.window?.orderOut(nil)
                self?.window = nil
            }
        })
    }
}

struct StartupToastView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 14) {
            // App icon with subtle animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "clipboard.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isAnimating)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("ClipArc")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(L10n.Toast.running)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Checkmark indicator
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
                .opacity(isAnimating ? 1 : 0)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.2), value: isAnimating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 280, height: 72)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    StartupToastView()
        .padding()
        .background(Color.gray.opacity(0.2))
}
