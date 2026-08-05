//
//  SensitiveContentDetectorTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-08-05.
//

import XCTest
@testable import ClipArc

final class SensitiveContentDetectorTests: XCTestCase {

    private func detect(_ content: String, sourceApp: String? = nil) -> SensitiveKind? {
        SensitiveContentDetector.detect(
            content: content,
            type: ClipboardItem.detectType(content),
            sourceAppBundleID: sourceApp
        )
    }

    // MARK: - Credentials

    func testPasswordShapedStringsAreDetected() {
        XCTAssertEqual(detect("Xy7!kLm9qR"), .password)
        XCTAssertEqual(detect("Tr0ub4dor&3"), .password)
        XCTAssertEqual(detect("Passw0rdAbcd"), .password)  // 12 chars, 3 classes, no symbol
    }

    func testEverydayTextIsNotFlaggedAsPassword() {
        XCTAssertNil(detect("Hello, World!"))
        XCTAssertNil(detect("meeting at 3pm tomorrow"))
        XCTAssertNil(detect("今天下午三点开会"))
        XCTAssertNil(detect("MyVariable1"))          // < 12 chars, no symbol
        XCTAssertNil(detect("com.example.app2"))     // reverse-DNS identifier
        XCTAssertNil(detect("some-file-name-42"))    // slug
        XCTAssertNil(detect("my_var_123"))           // snake_case identifier
        XCTAssertNil(detect("https://example.com/a1B2c3!"))
    }

    func testSecretKeysAreDetected() {
        XCTAssertEqual(detect("sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz012345"), .secretKey)
        XCTAssertEqual(detect("ghp_AbCdEfGhIjKlMnOpQrStUvWxYz01234567"), .secretKey)
        XCTAssertEqual(detect("AKIAIOSFODNN7EXAMPLE"), .secretKey)
        XCTAssertEqual(detect("xoxb-1234567890-abcdefghij"), .secretKey)
        XCTAssertEqual(
            detect("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dBjftJeZ4CVPmB92K27uhbUJU1p1r_wW1gFWFOEjXk"),
            .secretKey
        )
        XCTAssertEqual(
            detect("-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAA\n-----END OPENSSH PRIVATE KEY-----"),
            .secretKey
        )
    }

    func testPasswordManagerSourceMarksContentAsCredential() {
        XCTAssertEqual(detect("correct horse battery", sourceApp: "com.1password.1password"), .password)
        XCTAssertEqual(detect("plainword", sourceApp: "org.keepassxc.keepassxc"), .password)
        XCTAssertNil(detect("correct horse battery", sourceApp: "com.apple.Safari"))
    }

    // MARK: - Personal data

    func testCardNumbersAreDetectedViaLuhn() {
        XCTAssertEqual(detect("4111 1111 1111 1111"), .creditCard)
        XCTAssertEqual(detect("5500005555555559"), .creditCard)
        XCTAssertNil(detect("4111 1111 1111 1112"))  // fails Luhn
    }

    func testIdNumbersAreDetected() {
        XCTAssertEqual(detect("11010519900307123X"), .idNumber)
        XCTAssertEqual(detect("123-45-6789"), .idNumber)
    }

    func testEmailAndPhoneAreDetected() {
        XCTAssertEqual(detect("adam.fw.lyu@gmail.com"), .email)
        XCTAssertEqual(detect("+1 (415) 555-2671"), .phone)
        XCTAssertEqual(detect("13800138000"), .phone)
    }

    func testDatesAreNotMistakenForPhoneNumbers() {
        XCTAssertNil(detect("2026-08-05"))
        XCTAssertNil(detect("08/05/2026"))
    }

    // MARK: - Masking

    func testPasswordMaskKeepsBothEndsSoEntriesStayTellable() {
        let masked = SensitiveMask.mask("Ab3!middlepart!9yz", kind: .password)

        XCTAssertTrue(masked.hasPrefix("Ab"), "The first characters identify which password this is")
        XCTAssertTrue(masked.hasSuffix("yz"))
        XCTAssertFalse(masked.contains("middlepart"), "The body must stay hidden")
    }

    func testTwoPasswordsWithDifferentBodiesLookDifferent() {
        let a = SensitiveMask.mask("Gm4!lorem!ipsum9", kind: .password)
        let b = SensitiveMask.mask("Tw7!dolor!sitame3", kind: .password)
        XCTAssertNotEqual(a, b, "A history of passwords must not render as identical rows")
    }

    func testPasswordMaskDoesNotLeakLength() {
        let short = SensitiveMask.mask("Ab" + String(repeating: "x", count: 10) + "yz", kind: .password)
        let long = SensitiveMask.mask("Ab" + String(repeating: "x", count: 60) + "yz", kind: .password)
        XCTAssertEqual(short, long, "The number of bullets must not track the real length")
        XCTAssertEqual(short, "Ab••••••yz")
    }

    func testVeryShortSecretsRevealNothing() {
        // Two revealed characters would be a quarter of an 7-character secret.
        let masked = SensitiveMask.mask("Ab3!xy", kind: .password)
        XCTAssertEqual(masked, "••••••")
    }

    func testSecretKeyMaskKeepsVendorPrefixAndLastFour() {
        XCTAssertEqual(
            SensitiveMask.mask("sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz", kind: .secretKey),
            "sk-proj-••••••WxYz"
        )
        XCTAssertEqual(
            SensitiveMask.mask("ghp_AbCdEfGhIjKlMnOpQrStUv0123456789", kind: .secretKey),
            "ghp_••••••6789"
        )
        // No separator to key off: fall back to the leading characters.
        XCTAssertEqual(
            SensitiveMask.mask("AKIAIOSFODNN7EXAMPLE", kind: .secretKey),
            "AKIA••••••MPLE"
        )
    }

    func testEveryKindKeepsSomethingRecognisable() {
        // No kind may render as an anonymous blob of bullets - the user has to be
        // able to pick the right entry without revealing it first.
        let samples: [(SensitiveKind, String)] = [
            (.password, "Ab3!middlepart!9yz"),
            (.secretKey, "sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz"),
            (.email, "adam.fw.lyu@gmail.com"),
            (.phone, "+1 (415) 555-2671"),
            (.creditCard, "4111 1111 1111 1234"),
            (.idNumber, "11010519900307123X"),
        ]

        for (kind, sample) in samples {
            let masked = SensitiveMask.mask(sample, kind: kind)
            XCTAssertFalse(masked.allSatisfy { $0 == "•" || $0 == " " },
                           "\(kind) renders as bullets only")
            XCTAssertFalse(masked.contains(sample), "\(kind) leaks the whole value")
        }
    }

    func testMaskKeepsEmailRecognisable() {
        let masked = SensitiveMask.mask("adam.fw.lyu@gmail.com", kind: .email)
        XCTAssertTrue(masked.hasPrefix("ad"))
        XCTAssertTrue(masked.hasSuffix("@gmail.com"))
        XCTAssertFalse(masked.contains("fw.lyu"))
    }

    func testMaskKeepsCardLastFour() {
        XCTAssertEqual(SensitiveMask.mask("4111 1111 1111 1234", kind: .creditCard), "•••• •••• •••• 1234")
    }

    func testMaskedPreviewNeverAltersStoredContent() {
        let secret = "Xy7!kLm9qR"
        let item = ClipboardItem(content: secret, type: .text)
        item.sensitiveKind = .password

        XCTAssertNotEqual(item.maskedPreview, secret)
        XCTAssertEqual(item.content, secret, "Masking must never change what gets pasted")
    }

    func testNonSensitiveItemPreviewIsUnchanged() {
        let item = ClipboardItem(content: "Hello, World!", type: .text)
        XCTAssertFalse(item.isSensitive)
        XCTAssertEqual(item.maskedPreview, item.previewText)
    }
}
