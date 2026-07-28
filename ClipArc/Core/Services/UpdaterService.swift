//
//  UpdaterService.swift
//  ClipArc
//
//  In-app auto-update via Sparkle.
//  Direct (non-sandboxed, website-distributed) build only — the App Store
//  build compiles this file out entirely via `#if !APPSTORE`.
//

#if !APPSTORE
import Combine
import Foundation
import Sparkle

/// Thin wrapper around Sparkle's standard updater controller.
///
/// Configuration lives in Info.plist (`SUFeedURL`, `SUPublicEDKey`,
/// `SUEnableAutomaticChecks`, `SUScheduledCheckInterval`). See UPDATES_SETUP.md
/// for how to generate signing keys and host the appcast.
@MainActor
final class UpdaterService: ObservableObject {
    static let shared = UpdaterService()

    private let controller: SPUStandardUpdaterController

    /// Whether an update check can be started right now
    /// (feed reachable/configured and no check already in progress).
    @Published private(set) var canCheckForUpdates = false

    private init() {
        // startingUpdater: true — Sparkle starts on launch and honors the
        // scheduled-check settings from Info.plist. It only surfaces UI when
        // an update is actually found or the user checks manually.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)

        Logger.debug("UpdaterService initialized (auto-check: \(controller.updater.automaticallyChecksForUpdates))")
    }

    /// Whether Sparkle checks for updates automatically on a schedule.
    /// Backed by Sparkle's own persisted setting.
    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    /// User-initiated update check. Shows Sparkle's standard update UI.
    func checkForUpdates() {
        Logger.debug("Manual update check requested")
        controller.updater.checkForUpdates()
    }
}
#endif
