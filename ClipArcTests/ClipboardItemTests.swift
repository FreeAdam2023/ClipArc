//
//  ClipboardItemTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-21.
//

import XCTest
@testable import ClipArc

final class ClipboardItemTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitWithTextContent() {
        let item = ClipboardItem(
            content: "Hello, World!",
            type: .text,
            sourceAppName: "Safari"
        )

        XCTAssertEqual(item.content, "Hello, World!")
        XCTAssertEqual(item.type, .text)
        XCTAssertEqual(item.sourceAppName, "Safari")
        XCTAssertNotNil(item.id)
        XCTAssertFalse(item.contentHash.isEmpty)
    }

    func testInitWithURLContent() {
        let item = ClipboardItem(
            content: "https://apple.com",
            type: .url,
            sourceAppBundleID: "com.apple.Safari"
        )

        XCTAssertEqual(item.content, "https://apple.com")
        XCTAssertEqual(item.type, .url)
        XCTAssertEqual(item.sourceAppBundleID, "com.apple.Safari")
    }

    // MARK: - Content Hash Tests

    func testContentHashConsistency() {
        let content = "Test content"
        let hash1 = ClipboardItem.computeHash(content)
        let hash2 = ClipboardItem.computeHash(content)

        XCTAssertEqual(hash1, hash2)
    }

    func testDifferentContentDifferentHash() {
        let hash1 = ClipboardItem.computeHash("Content A")
        let hash2 = ClipboardItem.computeHash("Content B")

        XCTAssertNotEqual(hash1, hash2)
    }

    func testHashIsValidSHA256() {
        let hash = ClipboardItem.computeHash("test")
        // SHA256 produces 64 hex characters
        XCTAssertEqual(hash.count, 64)
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }

    // MARK: - Preview Generation Tests

    func testGeneratePreviewShortText() {
        let preview = ClipboardItem.generatePreview("Short text")
        XCTAssertEqual(preview, "Short text")
    }

    func testGeneratePreviewLongText() {
        let longText = String(repeating: "a", count: 200)
        let preview = ClipboardItem.generatePreview(longText, maxLength: 100)

        XCTAssertLessThanOrEqual(preview.count, 100)
        XCTAssertTrue(preview.hasSuffix("..."))
    }

    func testGeneratePreviewMultipleLines() {
        let multilineText = "Line 1\nLine 2\nLine 3"
        let preview = ClipboardItem.generatePreview(multilineText)

        XCTAssertEqual(preview, "Line 1 Line 2")
    }

    func testGeneratePreviewTrimsWhitespace() {
        let textWithWhitespace = "   Hello World   \n   "
        let preview = ClipboardItem.generatePreview(textWithWhitespace)

        XCTAssertEqual(preview, "Hello World")
    }

    // MARK: - Type Detection Tests

    func testDetectTextType() {
        let type = ClipboardItem.detectType("Just some text")
        XCTAssertEqual(type, .text)
    }

    func testDetectHTTPURLType() {
        let type = ClipboardItem.detectType("https://example.com")
        XCTAssertEqual(type, .url)
    }

    func testDetectHTTPWithoutS() {
        let type = ClipboardItem.detectType("http://example.com")
        XCTAssertEqual(type, .url)
    }

    func testDetectFTPURLType() {
        let type = ClipboardItem.detectType("ftp://files.example.com")
        XCTAssertEqual(type, .url)
    }

    func testDetectFileURLType() {
        let type = ClipboardItem.detectType("file:///Users/test/file.txt")
        XCTAssertEqual(type, .url)
    }

    func testInvalidURLAsText() {
        let type = ClipboardItem.detectType("not a valid url")
        XCTAssertEqual(type, .text)
    }

    func testURLWithWhitespaceTrimsAndDetects() {
        let type = ClipboardItem.detectType("  https://example.com  ")
        XCTAssertEqual(type, .url)
    }
}

// MARK: - ClipboardItemType Tests

final class ClipboardItemTypeTests: XCTestCase {

    func testTextTypeProperties() {
        let type = ClipboardItemType.text
        XCTAssertEqual(type.rawValue, "text")
        XCTAssertEqual(type.icon, "doc.text")
        XCTAssertEqual(type.displayName, "Text")
    }

    func testURLTypeProperties() {
        let type = ClipboardItemType.url
        XCTAssertEqual(type.rawValue, "url")
        XCTAssertEqual(type.icon, "link")
        XCTAssertEqual(type.displayName, "URL")
    }

    func testAllCases() {
        let allCases = ClipboardItemType.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.text))
        XCTAssertTrue(allCases.contains(.url))
    }
}
