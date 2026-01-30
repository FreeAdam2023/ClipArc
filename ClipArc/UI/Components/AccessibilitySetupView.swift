//
//  AccessibilitySetupView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-23.
//

import SwiftUI

/// A guided setup view for enabling accessibility access, similar to Paste app
struct AccessibilitySetupView: View {
    let onOpenSettings: () -> Void
    let onHelpTapped: () -> Void
    let onDismiss: () -> Void
    let showHelpButton: Bool

    @State private var isAnimating = false

    init(
        onOpenSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        showHelpButton: Bool = false,
        onHelpTapped: @escaping () -> Void = {}
    ) {
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
        self.showHelpButton = showHelpButton
        self.onHelpTapped = onHelpTapped
    }

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(16)
            }

            Spacer().frame(height: 20)

            // App Icon
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)

            Spacer().frame(height: 24)

            // Title
            Text(L10n.Accessibility.setupTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Spacer().frame(height: 12)

            // Subtitle
            Text(L10n.Accessibility.setupSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 32)

            // System Settings Mock
            SystemSettingsMockView()
                .scaleEffect(isAnimating ? 1.0 : 0.95)
                .opacity(isAnimating ? 1.0 : 0.8)
                .padding(.horizontal, 24)

            Spacer().frame(height: 32)

            // Buttons
            HStack(spacing: 16) {
                // Help button (shown after failed attempt)
                if showHelpButton {
                    Button(action: onHelpTapped) {
                        Text(L10n.Accessibility.havingIssue)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(height: 44)
                            .padding(.horizontal, 24)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)
                }

                // Open System Settings Button
                Button(action: onOpenSettings) {
                    Text(L10n.Accessibility.openSystemSettings)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(height: 44)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer().frame(height: 40)
        }
        .frame(width: 520, height: 680)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.18, blue: 0.35),
                    Color(red: 0.10, green: 0.12, blue: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - System Settings Mock View

struct SystemSettingsMockView: View {
    @State private var highlightVisible = false

    var body: some View {
        // Outer container with gradient background
        ZStack {
            // Background gradient (macOS Sonoma style)
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.3, green: 0.5, blue: 0.5),
                            Color(red: 0.2, green: 0.4, blue: 0.45),
                            Color(red: 0.25, green: 0.45, blue: 0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // System Settings Window
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 0) {
                    // Window controls
                    HStack(spacing: 6) {
                        Circle().fill(Color.red.opacity(0.9)).frame(width: 10, height: 10)
                        Circle().fill(Color.yellow.opacity(0.9)).frame(width: 10, height: 10)
                        Circle().fill(Color.green.opacity(0.9)).frame(width: 10, height: 10)
                    }
                    .padding(.leading, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                    // Sidebar items
                    VStack(alignment: .leading, spacing: 2) {
                        SidebarItem(icon: "accessibility", text: "Accessibility", isSelected: false)
                        SidebarItem(icon: "paintbrush", text: "Appearance", isSelected: false)
                        SidebarItem(icon: "desktopcomputer", text: "Desktop & Dock", isSelected: false)
                        SidebarItem(icon: "display", text: "Displays", isSelected: false)
                        SidebarItem(icon: "menubar.rectangle", text: "Menu Bar", isSelected: false)

                        Spacer().frame(height: 8)

                        SidebarItem(icon: "bell.badge", text: "Notifications", isSelected: false)
                        SidebarItem(icon: "speaker.wave.2", text: "Sound", isSelected: false)
                        SidebarItem(icon: "moon", text: "Focus", isSelected: false)

                        Spacer().frame(height: 8)

                        SidebarItem(icon: "lock.shield", text: "Privacy & Security", isSelected: true)
                    }
                    .padding(.horizontal, 6)

                    Spacer()
                }
                .frame(width: 140)
                .background(Color.black.opacity(0.25))

                // Main content
                VStack(alignment: .leading, spacing: 0) {
                    // Navigation bar
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))

                        Text("Accessibility")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.leading, 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)

                    Divider().background(Color.white.opacity(0.1))

                    // Content area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Allow the applications below to control your computer.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.top, 8)

                        // App list
                        VStack(spacing: 4) {
                            // ClipArc row (highlighted)
                            HStack(spacing: 10) {
                                Image("AppIconImage")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                Text("ClipArc")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white)

                                Spacer()

                                // Toggle (on state)
                                ZStack {
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .frame(width: 38, height: 22)

                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 18, height: 18)
                                        .offset(x: 8)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(highlightVisible ? 0.15 : 0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentColor.opacity(highlightVisible ? 0.8 : 0), lineWidth: 2)
                                    )
                            )
                            .scaleEffect(highlightVisible ? 1.02 : 1.0)

                            // Add/Remove buttons
                            HStack(spacing: 0) {
                                Button(action: {}) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .frame(width: 24, height: 20)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .frame(height: 14)
                                    .background(Color.white.opacity(0.2))

                                Button(action: {}) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .frame(width: 24, height: 20)
                                }
                                .buttonStyle(.plain)
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer()
                }
                .background(Color.black.opacity(0.35))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 15, y: 8)
            .padding(20)
        }
        .frame(height: 280)
        .onAppear {
            // Animate the highlight
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.5)) {
                highlightVisible = true
            }
        }
    }
}

struct SidebarItem: View {
    let icon: String
    let text: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                .frame(width: 18)

            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}

#Preview("Without Help Button") {
    AccessibilitySetupView(
        onOpenSettings: {},
        onDismiss: {}
    )
    .padding(40)
    .background(Color.gray)
}

#Preview("With Help Button") {
    AccessibilitySetupView(
        onOpenSettings: {},
        onDismiss: {},
        showHelpButton: true,
        onHelpTapped: {}
    )
    .padding(40)
    .background(Color.gray)
}
