//
//  DataMigration.swift
//  ClipArc
//
//  One-time migration of the SwiftData store from the old sandboxed container
//  to the non-sandbox Application Support location used by the Direct build.
//
//  Sandboxed and non-sandboxed apps resolve different default store paths, so
//  a user upgrading from the sandboxed (App Store) build to the Direct build
//  would otherwise see an empty history — the old data still lives in the
//  sandbox container. This copies it over once, on first Direct-build launch.
//
//  Direct build only (#if !APPSTORE): the non-sandboxed app has full disk
//  access and can read the old sandbox container.
//

#if !APPSTORE
import Foundation

enum DataMigration {
    static let migrationFlagKey = "didMigrateSandboxStore.v1"
    static let storeName = "default.store"
    // SQLite WAL sidecar files must travel with the main store to stay consistent.
    static let sidecarSuffixes = ["", "-wal", "-shm"]

    /// Old sandboxed container's Application Support directory for this app.
    static var defaultSandboxBase: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.versegates.ClipArc/Data/Library/Application Support")
    }

    /// Non-sandbox Application Support directory (where the Direct build stores data).
    static var defaultAppSupport: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    /// Run once, before the ModelContainer is created on Direct-build launch.
    static func migrateFromSandboxIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: migrationFlagKey) else { return }
        guard let appSupport = defaultAppSupport else { return }
        let copied = performMigration(sandboxBase: defaultSandboxBase, appSupport: appSupport)
        if copied {
            Logger.notice("Migrated clipboard history from sandbox container")
        }
        defaults.set(true, forKey: migrationFlagKey)
    }

    /// Copies the sandbox store into `appSupport` iff the destination has no
    /// store yet and the sandbox source exists. Never overwrites existing data.
    /// Returns true if data was copied.
    @discardableResult
    static func performMigration(sandboxBase: URL, appSupport: URL, fileManager fm: FileManager = .default) -> Bool {
        let dest = appSupport.appendingPathComponent(storeName)
        // Never clobber an existing non-sandbox store.
        guard !fm.fileExists(atPath: dest.path) else { return false }

        let src = sandboxBase.appendingPathComponent(storeName)
        guard fm.fileExists(atPath: src.path) else { return false }

        do {
            try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
            for suffix in sidecarSuffixes {
                let s = sandboxBase.appendingPathComponent(storeName + suffix)
                let d = appSupport.appendingPathComponent(storeName + suffix)
                guard fm.fileExists(atPath: s.path) else { continue }
                try? fm.removeItem(at: d)
                try fm.copyItem(at: s, to: d)
            }
            return true
        } catch {
            Logger.error("Sandbox store migration failed", error: error)
            return false
        }
    }
}
#endif
