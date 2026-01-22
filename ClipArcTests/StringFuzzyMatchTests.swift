//
//  StringFuzzyMatchTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-21.
//

import XCTest
@testable import ClipArc

final class StringFuzzyMatchTests: XCTestCase {

    // MARK: - Basic Match Tests

    func testEmptyQueryMatches() {
        let result = "Hello World".fuzzyMatch("")
        XCTAssertTrue(result.matches)
        XCTAssertEqual(result.score, 0)
    }

    func testExactMatchHighScore() {
        let result = "hello".fuzzyMatch("hello")
        XCTAssertTrue(result.matches)
        XCTAssertGreaterThan(result.score, 100)
    }

    func testSubstringMatch() {
        let result = "Hello World".fuzzyMatch("World")
        XCTAssertTrue(result.matches)
        XCTAssertGreaterThan(result.score, 0)
    }

    func testCaseInsensitiveMatch() {
        let result = "HELLO WORLD".fuzzyMatch("hello")
        XCTAssertTrue(result.matches)
    }

    // MARK: - Fuzzy Match Tests

    func testFuzzyCharacterMatch() {
        let result = "clipboard".fuzzyMatch("clpbrd")
        XCTAssertTrue(result.matches)
    }

    func testFuzzyMatchSkipsCharacters() {
        let result = "abcdefghij".fuzzyMatch("acegi")
        XCTAssertTrue(result.matches)
    }

    // MARK: - Non-Match Tests

    func testNoMatchReturnsFalse() {
        let result = "hello".fuzzyMatch("xyz")
        XCTAssertFalse(result.matches)
        XCTAssertEqual(result.score, 0)
    }

    func testPartialQueryNoMatch() {
        let result = "abc".fuzzyMatch("abcd")
        XCTAssertFalse(result.matches)
    }

    // MARK: - Score Tests

    func testConsecutiveMatchesHigherScore() {
        let result1 = "abcdef".fuzzyMatch("abc")
        let result2 = "axbxcxdef".fuzzyMatch("abc")

        XCTAssertTrue(result1.matches)
        XCTAssertTrue(result2.matches)
        XCTAssertGreaterThan(result1.score, result2.score)
    }

    func testShorterStringsBonus() {
        let shortResult = "abc".fuzzyMatch("abc")
        let longResult = "abcdefghijklmnopqrstuvwxyz".fuzzyMatch("abc")

        XCTAssertGreaterThan(shortResult.score, longResult.score)
    }

    func testContainsMatchHighScore() {
        let containsResult = "hello world".fuzzyMatch("world")
        XCTAssertTrue(containsResult.matches)
        XCTAssertGreaterThan(containsResult.score, 100)
    }

    // MARK: - Edge Cases

    func testSingleCharacterMatch() {
        let result = "a".fuzzyMatch("a")
        XCTAssertTrue(result.matches)
    }

    func testSingleCharacterNoMatch() {
        let result = "a".fuzzyMatch("b")
        XCTAssertFalse(result.matches)
    }

    func testSpecialCharactersMatch() {
        let result = "hello@world.com".fuzzyMatch("@world")
        XCTAssertTrue(result.matches)
    }

    func testUnicodeMatch() {
        let result = "你好世界".fuzzyMatch("你好")
        XCTAssertTrue(result.matches)
    }

    func testEmojiMatch() {
        let result = "Hello 👋 World".fuzzyMatch("👋")
        XCTAssertTrue(result.matches)
    }
}
