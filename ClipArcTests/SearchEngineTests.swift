//
//  SearchEngineTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-21.
//

import XCTest
@testable import ClipArc

final class SearchEngineTests: XCTestCase {

    var testItems: [ClipboardItem]!

    override func setUp() {
        super.setUp()
        testItems = [
            ClipboardItem(content: "Hello World", type: .text),
            ClipboardItem(content: "https://apple.com", type: .url),
            ClipboardItem(content: "Swift programming language", type: .text),
            ClipboardItem(content: "Xcode development", type: .text),
            ClipboardItem(content: "macOS Clipboard Manager", type: .text),
        ]
    }

    override func tearDown() {
        testItems = nil
        super.tearDown()
    }

    // MARK: - Empty Query Tests

    func testEmptyQueryReturnsAll() {
        let results = SearchEngine.filter(items: testItems, query: "")
        XCTAssertEqual(results.count, testItems.count)
    }

    func testWhitespaceQueryReturnsAll() {
        let results = SearchEngine.filter(items: testItems, query: "   ")
        XCTAssertEqual(results.count, testItems.count)
    }

    // MARK: - Filter Tests

    func testFilterByExactContent() {
        let results = SearchEngine.filter(items: testItems, query: "Hello World")

        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "Hello World")
    }

    func testFilterByPartialContent() {
        let results = SearchEngine.filter(items: testItems, query: "Swift")

        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertTrue(results.contains { $0.content.contains("Swift") })
    }

    func testCaseInsensitiveFilter() {
        let results = SearchEngine.filter(items: testItems, query: "HELLO")
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    func testNoResultsForNonMatching() {
        let results = SearchEngine.filter(items: testItems, query: "zzzznotfound")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Score Sorting Tests

    func testResultsSortedByScore() {
        let items = [
            ClipboardItem(content: "abc def ghi", type: .text),
            ClipboardItem(content: "abc", type: .text),
            ClipboardItem(content: "xyzabcxyz", type: .text),
        ]
        let results = SearchEngine.filter(items: items, query: "abc")

        XCTAssertEqual(results.count, 3)
        // Exact match or contains match should score highest
        XCTAssertEqual(results.first?.content, "abc")
    }

    // MARK: - Simple Filter Tests

    func testSimpleFilterWorks() {
        let results = SearchEngine.simpleFilter(items: testItems, query: "clipboard")

        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertTrue(results.contains { $0.content.lowercased().contains("clipboard") })
    }

    func testSimpleFilterCaseInsensitive() {
        let results = SearchEngine.simpleFilter(items: testItems, query: "CLIPBOARD")
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    func testSimpleFilterEmptyQuery() {
        let results = SearchEngine.simpleFilter(items: testItems, query: "")
        XCTAssertEqual(results.count, testItems.count)
    }

    // MARK: - URL Content Tests

    func testFilterFindsURL() {
        let results = SearchEngine.filter(items: testItems, query: "apple.com")
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertTrue(results.contains { $0.type == .url })
    }

    // MARK: - Performance Tests

    func testFilterPerformance() {
        // Create a large set of items
        var largeItemSet: [ClipboardItem] = []
        for i in 0..<1000 {
            largeItemSet.append(ClipboardItem(content: "Item number \(i) with some content", type: .text))
        }

        measure {
            _ = SearchEngine.filter(items: largeItemSet, query: "number 500")
        }
    }
}
