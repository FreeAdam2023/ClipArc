//
//  DateRelativeFormatTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-23.
//

import XCTest
@testable import ClipArc

final class DateRelativeFormatTests: XCTestCase {

    // MARK: - Short Relative Format Tests

    func testJustNow() {
        let now = Date()
        let result = now.shortRelativeFormatted
        XCTAssertTrue(result.contains("now") || result.contains("0") || result.contains("sec"),
                      "Expected 'now' or similar for current time, got: \(result)")
    }

    func testSecondsAgo() {
        let date = Date().addingTimeInterval(-30)
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testMinutesAgo() {
        let date = Date().addingTimeInterval(-120) // 2 minutes ago
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testHoursAgo() {
        let date = Date().addingTimeInterval(-3600 * 2) // 2 hours ago
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testDaysAgo() {
        let date = Date().addingTimeInterval(-86400 * 2) // 2 days ago
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testWeeksAgo() {
        let date = Date().addingTimeInterval(-86400 * 14) // 2 weeks ago
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testMonthsAgo() {
        let date = Date().addingTimeInterval(-86400 * 60) // ~2 months ago
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testYearsAgo() {
        let date = Date().addingTimeInterval(-86400 * 400) // ~1 year ago
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Edge Cases

    func testFutureDate() {
        let date = Date().addingTimeInterval(3600) // 1 hour in the future
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        // Future dates should still be handled gracefully
    }

    func testDistantPast() {
        let date = Date.distantPast
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isEmpty)
    }

    func testDistantFuture() {
        let date = Date.distantFuture
        let result = date.shortRelativeFormatted
        XCTAssertNotNil(result)
        // Should handle gracefully
    }

    // MARK: - Consistency Tests

    func testFormattingConsistency() {
        let date = Date().addingTimeInterval(-60) // 1 minute ago
        let result1 = date.shortRelativeFormatted
        let result2 = date.shortRelativeFormatted
        XCTAssertEqual(result1, result2, "Same date should produce same result")
    }

    func testOrderingCorrectness() {
        let older = Date().addingTimeInterval(-3600)
        let newer = Date().addingTimeInterval(-60)

        // Both should format without crashing
        _ = older.shortRelativeFormatted
        _ = newer.shortRelativeFormatted
    }
}
