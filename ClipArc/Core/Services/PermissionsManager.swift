//
//  PermissionsManager.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Foundation
import ServiceManagement

@MainActor
@Observable
final class PermissionsManager {
    static let shared = PermissionsManager()

    var isLaunchAtLoginEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            setLaunchAtLogin(newValue)
        }
    }

    private init() {}

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.error("Failed to set launch at login", error: error)
        }
    }

    func toggleLaunchAtLogin() {
        isLaunchAtLoginEnabled.toggle()
    }
}
