//
//  PanelComponents.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-23.
//

import AppKit
import SwiftUI

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
            withAnimation(.easeInOut(duration: TimingConstants.shortAnimationDuration)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Horizontal Empty State View

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
            .frame(width: UIConstants.cardWidth, height: UIConstants.cardHeight)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: UIConstants.largeCornerRadius)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: UIConstants.largeCornerRadius)
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
                RoundedRectangle(cornerRadius: UIConstants.largeCornerRadius)
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
            withAnimation(.easeInOut(duration: TimingConstants.mediumAnimationDuration)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - Visual Effect View

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

// MARK: - Subscription Window Helper

@MainActor
func openSubscriptionWindow(appState: AppState) {
    // Post notification to switch to subscription tab
    NotificationCenter.default.post(name: .openSubscriptionTab, object: nil)

    // Post notification to open settings window (using proper SwiftUI approach)
    NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
}
