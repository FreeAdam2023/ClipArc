//
//  StoreCompactionTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-08-05.
//

import SQLite3
import XCTest
@testable import ClipArc

final class StoreCompactionTests: XCTestCase {

    private var directory: URL!
    private var storeURL: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("StoreCompactionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appendingPathComponent("default.store")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Writes a row holding `marker`, then deletes it. The payload is large enough to
    /// spill onto overflow pages, so deleting it hands whole pages to the free list
    /// with their bytes intact - exactly what re-encrypting a history leaves behind.
    private func makeStoreWithDeletedRow(marker: String) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(storeURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let secretPayload = String(repeating: marker + " ", count: 2000)
        let statements = [
            "CREATE TABLE items (id INTEGER PRIMARY KEY, content TEXT);",
            "INSERT INTO items (content) VALUES ('\(secretPayload)');",
            // A surviving row keeps the file from simply being truncated to nothing.
            "INSERT INTO items (content) VALUES ('\(String(repeating: "padding ", count: 2000))');",
            "DELETE FROM items WHERE content LIKE '\(marker)%';",
        ]
        for statement in statements {
            XCTAssertEqual(sqlite3_exec(db, statement, nil, nil, nil), SQLITE_OK, statement)
        }
    }

    private func fileContainsMarker(_ marker: String) throws -> Bool {
        let data = try Data(contentsOf: storeURL)
        return data.range(of: Data(marker.utf8)) != nil
    }

    func testVacuumRemovesDeletedPlaintextFromTheFile() throws {
        let marker = "PLAINTEXT-MARKER-hunter2-do-not-leak"
        try makeStoreWithDeletedRow(marker: marker)

        XCTAssertTrue(try fileContainsMarker(marker),
                      "Precondition: a deleted row's bytes still sit in the file")

        XCTAssertTrue(StoreCompaction.vacuum(at: storeURL))

        XCTAssertFalse(try fileContainsMarker(marker),
                       "VACUUM must drop pages that still hold pre-encryption cleartext")
    }

    func testVacuumPreservesLiveRows() throws {
        try makeStoreWithDeletedRow(marker: "gone")
        XCTAssertTrue(StoreCompaction.vacuum(at: storeURL))

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(storeURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM items;", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        XCTAssertEqual(sqlite3_column_int(statement, 0), 1, "The surviving row must still be there")
    }

    // MARK: - Pending flag

    func testPendingFlagRoundTripsAndClearsAfterVacuum() throws {
        let suiteName = "StoreCompactionTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(defaults.bool(forKey: StoreCompaction.pendingKey))

        // This is the real sequence: the encryption pass marks it, the next launch reads it.
        StoreCompaction.markPending(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: StoreCompaction.pendingKey))

        StoreCompaction.vacuumIfPending(defaults: defaults)
        XCTAssertFalse(defaults.bool(forKey: StoreCompaction.pendingKey),
                       "The flag must clear so the vacuum does not repeat every launch")
    }

    func testVacuumIsSkippedWhenNotPending() throws {
        let suiteName = "StoreCompactionTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // No flag set: must be a no-op rather than an unnecessary full rebuild.
        StoreCompaction.vacuumIfPending(defaults: defaults)
        XCTAssertFalse(defaults.bool(forKey: StoreCompaction.pendingKey))
    }
}
