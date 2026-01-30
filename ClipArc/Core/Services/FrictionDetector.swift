//
//  FrictionDetector.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-30.
//

import Foundation
import SwiftUI

/// Detects user friction patterns to determine when to show Direct Paste enhancement guide
/// Uses behavior-driven detection instead of proactive prompting
@MainActor
@Observable
final class FrictionDetector {
    static let shared = FrictionDetector()

    // MARK: - Configuration

    /// Number of clicks on the SAME item within time window to trigger friction detection
    /// This is the strongest signal - user repeatedly needs the same content
    private let sameItemThreshold = 3

    /// Number of clicks on DIFFERENT items within time window to trigger friction detection
    private let multiItemThreshold = 5

    /// Time window in seconds for detecting friction patterns
    private let timeWindowSeconds: TimeInterval = 30

    /// Cooldown period after user dismisses guide (in seconds)
    private let cooldownSeconds: TimeInterval = 24 * 3600  // 24 hours

    // MARK: - State

    /// Click history for pattern detection
    private var clickHistory: [(itemID: UUID, timestamp: Date)] = []

    /// Timestamp when user last dismissed the guide
    private var guideDismissedAt: TimeInterval {
        get { UserDefaults.standard.double(forKey: "frictionGuideDismissedAt") }
        set { UserDefaults.standard.set(newValue, forKey: "frictionGuideDismissedAt") }
    }

    /// Whether friction guide has ever been shown
    private var guideShownCount: Int {
        get { UserDefaults.standard.integer(forKey: "frictionGuideShownCount") }
        set { UserDefaults.standard.set(newValue, forKey: "frictionGuideShownCount") }
    }

    /// Current friction state
    private(set) var currentState: FrictionState = .normal

    // MARK: - Public API

    /// Record an item click for friction detection
    func trackClick(itemID: UUID) {
        let now = Date()

        // Remove old entries outside the time window
        clickHistory = clickHistory.filter {
            now.timeIntervalSince($0.timestamp) < timeWindowSeconds * 2
        }

        // Add new click
        clickHistory.append((itemID, now))

        // Check if we should update state
        updateState()

        Logger.debug("FrictionDetector: tracked click, history count: \(clickHistory.count)")
    }

    /// Whether we should show the friction guide
    var shouldShowFrictionGuide: Bool {
        // Already using Direct Paste - no need to show
        guard !DirectPasteCapabilityManager.shared.canDirectPaste else {
            Logger.debug("FrictionDetector: shouldShowGuide=false (Direct Paste already enabled)")
            return false
        }

        // In cooldown period - don't show
        let now = Date().timeIntervalSince1970
        if now - guideDismissedAt < cooldownSeconds {
            Logger.debug("FrictionDetector: shouldShowGuide=false (in cooldown)")
            return false
        }

        // Limit total number of times guide is shown (max 3 times ever)
        if guideShownCount >= 3 {
            Logger.debug("FrictionDetector: shouldShowGuide=false (shown \(guideShownCount) times already)")
            return false
        }

        // Check if friction signal is detected
        let result = currentState == .frictionDetected
        Logger.debug("FrictionDetector: shouldShowGuide=\(result) (state=\(currentState), shownCount=\(guideShownCount))")
        return result
    }

    /// User chose "Maybe Later" - enter cooldown
    func userDismissedGuide() {
        guideDismissedAt = Date().timeIntervalSince1970
        currentState = .cooldown
        clickHistory.removeAll()
        Logger.debug("FrictionDetector: user dismissed guide, entering cooldown")
    }

    /// User chose to enable Direct Paste
    func userAcceptedGuide() {
        guideShownCount += 1
        currentState = .guiding
        Logger.debug("FrictionDetector: user accepted guide")
    }

    /// Mark that guide was shown
    func markGuideShown() {
        guideShownCount += 1
    }

    /// Reset friction detection (e.g., when window closes)
    func resetDetection() {
        clickHistory.removeAll()
        if currentState == .frictionDetected {
            currentState = .normal
        }
    }

    // MARK: - Private

    private func updateState() {
        // Don't update if already in special states
        guard currentState == .normal || currentState == .frictionDetected else {
            return
        }

        if detectFrictionSignal() {
            currentState = .frictionDetected
        } else {
            currentState = .normal
        }
    }

    private func detectFrictionSignal() -> Bool {
        let now = Date()
        let recentClicks = clickHistory.filter {
            now.timeIntervalSince($0.timestamp) < timeWindowSeconds
        }

        // Signal 1 (Strongest): Same item clicked 3+ times in 30 seconds
        // This indicates user needs the same content repeatedly but has to
        // come back to ClipArc each time - clear workflow friction
        let groupedByItem = Dictionary(grouping: recentClicks, by: { $0.itemID })
        for (_, clicks) in groupedByItem {
            if clicks.count >= sameItemThreshold {
                Logger.debug("FrictionDetector: same item clicked \(clicks.count) times - friction detected")
                return true
            }
        }

        // Signal 2 (Secondary): 5+ different items in 30 seconds
        // Indicates heavy clipboard usage session
        if recentClicks.count >= multiItemThreshold {
            Logger.debug("FrictionDetector: \(recentClicks.count) clicks in time window - friction detected")
            return true
        }

        return false
    }

    private init() {}

    // MARK: - Testing Support

    /// Reset all state (for testing)
    func resetAllState() {
        clickHistory.removeAll()
        currentState = .normal
        UserDefaults.standard.removeObject(forKey: "frictionGuideDismissedAt")
        UserDefaults.standard.removeObject(forKey: "frictionGuideShownCount")
    }

    // MARK: - Types

    enum FrictionState {
        case normal           // Default state, just copy + toast
        case frictionDetected // Friction detected, can show guide
        case guiding          // Currently showing guide
        case cooldown         // User dismissed, in cooldown period
    }
}
