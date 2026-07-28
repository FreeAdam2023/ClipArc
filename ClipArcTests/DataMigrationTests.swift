//
//  DataMigrationTests.swift
//  ClipArcTests
//

#if !APPSTORE
import XCTest
@testable import ClipArc

final class DataMigrationTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipmig-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func writeStore(in dir: URL, suffixes: [String], content: String) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for s in suffixes {
            try content.data(using: .utf8)!
                .write(to: dir.appendingPathComponent("default.store\(s)"))
        }
    }

    func testMigratesStoreAndSidecarsWhenDestinationEmpty() throws {
        let sandbox = tmp.appendingPathComponent("sandbox")
        let appSupport = tmp.appendingPathComponent("appsupport")
        try writeStore(in: sandbox, suffixes: ["", "-wal", "-shm"], content: "history")

        let copied = DataMigration.performMigration(sandboxBase: sandbox, appSupport: appSupport)

        XCTAssertTrue(copied)
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: appSupport.appendingPathComponent("default.store").path))
        XCTAssertTrue(fm.fileExists(atPath: appSupport.appendingPathComponent("default.store-wal").path))
        XCTAssertTrue(fm.fileExists(atPath: appSupport.appendingPathComponent("default.store-shm").path))
        let migrated = try String(contentsOf: appSupport.appendingPathComponent("default.store"), encoding: .utf8)
        XCTAssertEqual(migrated, "history")
    }

    func testDoesNotOverwriteExistingDestinationStore() throws {
        let sandbox = tmp.appendingPathComponent("sandbox")
        let appSupport = tmp.appendingPathComponent("appsupport")
        try writeStore(in: sandbox, suffixes: [""], content: "sandbox")
        try writeStore(in: appSupport, suffixes: [""], content: "existing")

        let copied = DataMigration.performMigration(sandboxBase: sandbox, appSupport: appSupport)

        XCTAssertFalse(copied)
        let kept = try String(contentsOf: appSupport.appendingPathComponent("default.store"), encoding: .utf8)
        XCTAssertEqual(kept, "existing", "must not clobber an existing non-sandbox store")
    }

    func testNoOpWhenSandboxSourceMissing() throws {
        let sandbox = tmp.appendingPathComponent("sandbox")  // never created
        let appSupport = tmp.appendingPathComponent("appsupport")

        let copied = DataMigration.performMigration(sandboxBase: sandbox, appSupport: appSupport)

        XCTAssertFalse(copied)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: appSupport.appendingPathComponent("default.store").path))
    }
}
#endif
