//
//  UIConstants.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-23.
//

import Foundation

/// UI layout constants for consistent spacing and sizing across the app
enum UIConstants {
    // MARK: - Panel
    static let panelHorizontalPadding: CGFloat = 16
    static let panelTopPadding: CGFloat = 12
    static let panelBottomPadding: CGFloat = 8
    static let cardSpacing: CGFloat = 16
    static let searchBarWidth: CGFloat = 200

    // MARK: - Card
    static let cardWidth: CGFloat = 260
    static let cardHeight: CGFloat = 240
    static let cardCornerRadius: CGFloat = 16
    static let selectedBorderWidth: CGFloat = 2.5
    static let cardHorizontalPadding: CGFloat = 12
    static let cardVerticalPadding: CGFloat = 12

    // MARK: - Image Preview
    static let imagePreviewMaxWidth: CGFloat = 220
    static let imagePreviewMaxHeight: CGFloat = 150
    static let thumbnailWidth: CGFloat = 220
    static let thumbnailHeight: CGFloat = 130

    // MARK: - Settings Window
    static let settingsWindowWidth: CGFloat = 500
    static let settingsWindowHeight: CGFloat = 520
    static let avatarSize: CGFloat = 80

    // MARK: - Onboarding Window
    static let onboardingWindowWidth: CGFloat = 500
    static let onboardingWindowHeight: CGFloat = 600

    // MARK: - Common Spacing
    static let smallSpacing: CGFloat = 4
    static let mediumSpacing: CGFloat = 8
    static let largeSpacing: CGFloat = 16
    static let extraLargeSpacing: CGFloat = 24

    // MARK: - Corner Radius
    static let smallCornerRadius: CGFloat = 6
    static let mediumCornerRadius: CGFloat = 8
    static let largeCornerRadius: CGFloat = 12
}

/// Timing constants for animations and delays
enum TimingConstants {
    static let clipboardPollingInterval: TimeInterval = 0.5
    static let defaultPasteDelay: TimeInterval = 0.3
    static let appDeactivationDelay: TimeInterval = 0.05
    static let pasteDelay: TimeInterval = 0.35
    static let keyEventDelayMicroseconds: UInt32 = 10000
    static let shortAnimationDuration: TimeInterval = 0.15
    static let mediumAnimationDuration: TimeInterval = 0.2
    static let longAnimationDuration: TimeInterval = 0.35
}
