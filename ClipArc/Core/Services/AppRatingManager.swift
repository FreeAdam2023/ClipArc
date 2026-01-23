//
//  AppRatingManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-22.
//

import AppKit
import StoreKit
import SwiftUI

@MainActor
@Observable
final class AppRatingManager {
    static let shared = AppRatingManager()

    private let appStoreID = "6758185632"
    private let minimumActionsBeforePrompt = 10
    private let daysBetweenPrompts = 30

    private let lastPromptDateKey = "lastRatingPromptDate"
    private let actionCountKey = "ratingActionCount"
    private let hasRatedKey = "hasRatedApp"

    var showRatingPrompt = false
    private var ratingWindow: NSWindow?

    private init() {}

    // MARK: - Show Rating Window

    func showRatingWindow() {
        // Close existing window if any
        ratingWindow?.close()
        ratingWindow = nil

        let ratingView = RatingPromptView(
            onLike: { [weak self] in
                self?.userLikesApp()
                self?.closeRatingWindow()
            },
            onDislike: { [weak self] in
                self?.userHasIssues()
                self?.closeRatingWindow()
            },
            onDismiss: { [weak self] in
                self?.dismissPrompt()
                self?.closeRatingWindow()
            }
        )

        let hostingView = NSHostingView(rootView: ratingView)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 240),
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
        window.makeKeyAndOrderFront(nil)

        ratingWindow = window
        showRatingPrompt = false
    }

    private func closeRatingWindow() {
        ratingWindow?.close()
        ratingWindow = nil
    }

    // MARK: - Track User Actions

    /// Call this when user performs valuable actions (paste, copy, etc.)
    func trackAction() {
        let count = UserDefaults.standard.integer(forKey: actionCountKey) + 1
        UserDefaults.standard.set(count, forKey: actionCountKey)

        // Check if we should show rating prompt
        if shouldShowRatingPrompt() {
            // Delay to not interrupt user's current action
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showRatingWindow()
            }
        }
    }

    private func shouldShowRatingPrompt() -> Bool {
        // Don't show if already rated
        if UserDefaults.standard.bool(forKey: hasRatedKey) {
            return false
        }

        // Check minimum actions
        let actionCount = UserDefaults.standard.integer(forKey: actionCountKey)
        if actionCount < minimumActionsBeforePrompt {
            return false
        }

        // Check time since last prompt
        if let lastPromptDate = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPromptDate, to: Date()).day ?? 0
            if daysSinceLastPrompt < daysBetweenPrompts {
                return false
            }
        }

        return true
    }

    // MARK: - User Responses

    /// User says they like the app - redirect to App Store
    func userLikesApp() {
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
        UserDefaults.standard.set(true, forKey: hasRatedKey)
        showRatingPrompt = false

        // Open App Store review page
        if let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") {
            NSWorkspace.shared.open(url)
        }
    }

    /// User has issues - open email for feedback
    func userHasIssues() {
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
        UserDefaults.standard.set(true, forKey: hasRatedKey)  // Don't ask again after feedback
        showRatingPrompt = false

        // Collect device info for feedback
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        let subject = "ClipArc Feedback"
        let body = """


        ---
        App Version: \(appVersion) (\(buildNumber))
        macOS: \(osVersion)
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:support@versegates.com?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// User dismisses the prompt
    func dismissPrompt() {
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
        showRatingPrompt = false
    }

    /// Manually trigger rating prompt (e.g., from settings)
    func requestRating() {
        showRatingPrompt = true
    }

    /// Reset rating status (for testing)
    func resetRatingStatus() {
        UserDefaults.standard.removeObject(forKey: lastPromptDateKey)
        UserDefaults.standard.removeObject(forKey: actionCountKey)
        UserDefaults.standard.removeObject(forKey: hasRatedKey)
    }
}

// MARK: - Rating Prompt View

struct RatingPromptView: View {
    let onLike: () -> Void
    let onDislike: () -> Void
    let onDismiss: () -> Void

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 8)
            .padding(.top, 8)

            // App icon
            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0)

            // Title
            Text(L10n.Rating.title)
                .font(.system(size: 17, weight: .semibold))
                .padding(.top, 16)

            // Subtitle
            Text(L10n.Rating.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 4)

            // Buttons
            HStack(spacing: 12) {
                // Not really button (negative)
                Button(action: onDislike) {
                    Text(L10n.Rating.notReally)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                // Yes button (positive)
                Button(action: onLike) {
                    Text(L10n.Rating.yesLoveIt)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    RatingPromptView(
        onLike: {},
        onDislike: {},
        onDismiss: {}
    )
    .padding(40)
}
