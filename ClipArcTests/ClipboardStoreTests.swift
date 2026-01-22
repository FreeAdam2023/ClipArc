//
//  ClipboardStoreTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-21.
//

import XCTest
import SwiftData
@testable import ClipArc

@MainActor
final class ClipboardStoreTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var store: ClipboardStore!

    override func setUp() async throws {
        try await super.setUp()

        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: ClipboardItem.self, configurations: config)
        modelContext = modelContainer.mainContext
        store = ClipboardStore(modelContext: modelContext, historyLimit: 10)
    }

    override func tearDown() async throws {
        store = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Add Item Tests

    func testAddNewItem() async throws {
        store.add(content: "Hello World", type: .text)

        let items = store.fetchAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content, "Hello World")
        XCTAssertEqual(items.first?.type, .text)
    }

    func testAddItemWithSourceApp() async throws {
        store.add(
            content: "Test content",
            type: .text,
            sourceAppBundleID: "com.apple.Safari",
            sourceAppName: "Safari"
        )

        let items = store.fetchAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.sourceAppBundleID, "com.apple.Safari")
        XCTAssertEqual(items.first?.sourceAppName, "Safari")
    }

    func testAddURLItem() async throws {
        store.add(content: "https://apple.com", type: .url)

        let items = store.fetchAll()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.type, .url)
    }

    // MARK: - Deduplication Tests

    func testDuplicateContentUpdatesTimestamp() async throws {
        store.add(content: "Duplicate content", type: .text)

        // Wait a bit
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let firstItems = store.fetchAll()
        let originalDate = firstItems.first?.createdAt

        store.add(content: "Duplicate content", type: .text)

        let items = store.fetchAll()
        XCTAssertEqual(items.count, 1, "Should not create duplicate")
        XCTAssertGreaterThanOrEqual(items.first!.createdAt, originalDate!)
    }

    func testDifferentContentCreatesNewItems() async throws {
        store.add(content: "Content A", type: .text)
        store.add(content: "Content B", type: .text)

        let items = store.fetchAll()
        XCTAssertEqual(items.count, 2)
    }

    // MARK: - Delete Tests

    func testDeleteItem() async throws {
        store.add(content: "To be deleted", type: .text)

        var items = store.fetchAll()
        XCTAssertEqual(items.count, 1)

        store.delete(items.first!)

        items = store.fetchAll()
        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - Clear Tests

    func testClearAllItems() async throws {
        store.add(content: "Item 1", type: .text)
        store.add(content: "Item 2", type: .text)
        store.add(content: "Item 3", type: .text)

        var items = store.fetchAll()
        XCTAssertEqual(items.count, 3)

        store.clear()

        items = store.fetchAll()
        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - History Limit Tests

    func testHistoryLimitEnforced() async throws {
        let limitedStore = ClipboardStore(modelContext: modelContext, historyLimit: 5)

        for i in 0..<10 {
            limitedStore.add(content: "Item \(i)", type: .text)
        }

        let items = limitedStore.fetchAll()
        XCTAssertEqual(items.count, 5)
    }

    func testHistoryKeepsNewestItems() async throws {
        let limitedStore = ClipboardStore(modelContext: modelContext, historyLimit: 3)

        for i in 0..<5 {
            limitedStore.add(content: "Item \(i)", type: .text)
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }

        let items = limitedStore.fetchAll()
        XCTAssertEqual(items.count, 3)

        // Newest items should be kept
        let contents = items.map { $0.content }
        XCTAssertTrue(contents.contains("Item 4"))
        XCTAssertTrue(contents.contains("Item 3"))
        XCTAssertTrue(contents.contains("Item 2"))
    }

    // MARK: - Fetch Order Tests

    func testFetchAllReturnsSortedByDate() async throws {
        store.add(content: "First", type: .text)
        try await Task.sleep(nanoseconds: 10_000_000)
        store.add(content: "Second", type: .text)
        try await Task.sleep(nanoseconds: 10_000_000)
        store.add(content: "Third", type: .text)

        let items = store.fetchAll()
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].content, "Third")
        XCTAssertEqual(items[1].content, "Second")
        XCTAssertEqual(items[2].content, "First")
    }
}
