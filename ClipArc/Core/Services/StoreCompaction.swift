//
//  StoreCompaction.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-08-05.
//
//  Encrypting an existing history rewrites the rows, but SQLite keeps the
//  superseded pages in its free list - the pre-encryption cleartext is still
//  sitting in the file and `strings default.store` will happily print it.
//  VACUUM rebuilds the database from live data only, dropping those pages.
//
//  Must run while nothing has the store open, so it is invoked at launch just
//  before the ModelContainer is created.
//

import Foundation
import SQLite3

enum StoreCompaction {

    /// Set once legacy plaintext rows have been re-encrypted; cleared after the vacuum.
    static let pendingKey = "pendingStoreVacuum.v1"

    static let storeName = "default.store"

    static func markPending(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: pendingKey)
    }

    static var defaultStoreURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(storeName)
    }

    /// Rewrites the store if a re-encryption pass left stale cleartext pages behind.
    static func vacuumIfPending(defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: pendingKey) else { return }
        guard let url = defaultStoreURL,
              FileManager.default.fileExists(atPath: url.path) else {
            defaults.set(false, forKey: pendingKey)
            return
        }

        if vacuum(at: url) {
            Logger.notice("Compacted clipboard store to drop pre-encryption pages")
            defaults.set(false, forKey: pendingKey)
        }
    }

    /// Checkpoints the write-ahead log and rebuilds the database file.
    /// Returns true on success.
    @discardableResult
    static func vacuum(at url: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            Logger.error("Could not open the store for compaction")
            sqlite3_close(db)
            return false
        }
        defer { sqlite3_close(db) }

        // The WAL holds superseded pages too, so truncate it before rebuilding.
        for statement in ["PRAGMA wal_checkpoint(TRUNCATE);", "VACUUM;"] {
            var errorMessage: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(db, statement, nil, nil, &errorMessage) == SQLITE_OK else {
                let detail = errorMessage.map { String(cString: $0) } ?? "unknown error"
                sqlite3_free(errorMessage)
                Logger.error("Store compaction failed on \(statement): \(detail)")
                return false
            }
            sqlite3_free(errorMessage)
        }
        return true
    }
}
