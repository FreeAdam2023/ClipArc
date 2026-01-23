//
//  PasteService.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
enum PasteService {
    private static var alertWindow: NSWindow?

    /// Copy item to clipboard only (without simulating paste)
    static func copyItem(_ item: ClipboardItem, asPlainText: Bool = false) {
        print("[PasteService] copyItem called - type: \(item.type), content: \(item.content.prefix(50))")

        // Check content type
        if item.type == .image, let imageData = item.imageData {
            print("[PasteService] Copying image data (\(imageData.count) bytes)")
            copyImageToClipboard(imageData)
        } else if item.type == .file, !item.fileURLs.isEmpty {
            print("[PasteService] Copying \(item.fileURLs.count) file(s)")
            copyFilesToClipboard(item.fileURLs)
        } else {
            print("[PasteService] Copying text content")
            copyToClipboard(item.content, asPlainText: asPlainText)
        }
    }

    /// Copy item to clipboard and schedule paste after specified delay
    static func pasteItem(_ item: ClipboardItem, asPlainText: Bool = false, delay: TimeInterval = 0.3) {
        copyItem(item, asPlainText: asPlainText)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            print("[PasteService] Simulating paste after \(delay)s delay...")
            simulatePaste()
        }
    }

    static func copyToClipboard(_ content: String, asPlainText: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(content, forType: .string)
        print("[PasteService] copyToClipboard success: \(success), content length: \(content.count)")
    }

    static func copyImageToClipboard(_ imageData: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Set PNG data
        pasteboard.setData(imageData, forType: .png)

        // Also create NSImage and set TIFF for better compatibility
        if let image = NSImage(data: imageData) {
            pasteboard.writeObjects([image])
        }
    }

    static func copyFilesToClipboard(_ fileURLs: [URL]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // Write file URLs to pasteboard
        pasteboard.writeObjects(fileURLs as [NSURL])
    }

    static func simulatePaste() {
        let canPaste = canSimulatePaste()
        print("[PasteService] canSimulatePaste: \(canPaste)")

        // Verify clipboard has content
        let pasteboard = NSPasteboard.general
        let hasContent = pasteboard.string(forType: .string) != nil ||
                         pasteboard.data(forType: .png) != nil ||
                         pasteboard.readObjects(forClasses: [NSURL.self], options: nil) != nil
        print("[PasteService] Clipboard has content: \(hasContent)")

        guard canPaste else {
            print("[PasteService] Showing manual paste alert")
            showManualPasteAlert()
            return
        }
        print("[PasteService] Simulating Cmd+V...")

        let source = CGEventSource(stateID: .hidSystemState)

        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDownEvent?.flags = .maskCommand

        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUpEvent?.flags = .maskCommand

        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
    }

    static func canSimulatePaste() -> Bool {
        return AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private static func showManualPasteAlert() {
        // Close existing alert if any
        alertWindow?.close()
        alertWindow = nil

        // Get the app icon from bundle
        let appIcon: NSImage
        if let iconFile = Bundle.main.infoDictionary?["CFBundleIconFile"] as? String,
           let icon = NSImage(named: iconFile) {
            appIcon = icon
        } else if let icon = NSImage(named: NSImage.applicationIconName) {
            appIcon = icon
        } else {
            appIcon = NSApp.applicationIconImage ?? NSImage()
        }

        let alertView = AccessibilityAlertView(
            appIcon: appIcon,
            onOpenSettings: {
                openAccessibilitySettings()
                alertWindow?.close()
                alertWindow = nil
            },
            onDismiss: {
                alertWindow?.close()
                alertWindow = nil
            }
        )

        let hostingView = NSHostingView(rootView: alertView)

        let window = AlertPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 280),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .screenSaver  // Higher level to ensure visibility
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.center()

        // Ensure the app is activated and window is visible
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        alertWindow = window

        print("[PasteService] Alert window displayed at: \(window.frame)")
    }

    private static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Alert Panel

class AlertPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Elegant Alert View

struct AccessibilityAlertView: View {
    let appIcon: NSImage
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    @State private var isAnimating = false
    @State private var showHelp = false
    @State private var isOKHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with checkmark and help button
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.green)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0)
            }
            .padding(.top, 24)
            .overlay(alignment: .topTrailing) {
                // Help button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showHelp.toggle()
                    }
                }) {
                    Image(systemName: showHelp ? "xmark.circle.fill" : "questionmark.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(showHelp ? .secondary : .tertiary)
                }
                .buttonStyle(.plain)
                .offset(x: 90, y: 0)
            }

            // Title
            Text(L10n.Clipboard.copied)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 16)

            // Subtitle - show help text or ⌘V
            if showHelp {
                Text("Content copied to clipboard.\nPress ⌘V to paste manually,\nor enable auto-paste below.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Text("⌘V")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Divider
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.top, 20)

            // Permission hint
            Button(action: onOpenSettings) {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)

                    Text("Enable Auto-Paste")
                        .font(.system(size: 13))
                        .foregroundStyle(.blue)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // OK Button - more prominent
            Button(action: onDismiss) {
                Text("OK")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: isOKHovered ? [Color.blue, Color.blue.opacity(0.8)] : [Color.blue.opacity(0.9), Color.blue.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .scaleEffect(isOKHovered ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isOKHovered = hovering
                }
            }
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    AccessibilityAlertView(
        appIcon: NSImage(),
        onOpenSettings: {},
        onDismiss: {}
    )
    .padding(40)
    .background(Color.gray.opacity(0.3))
}
