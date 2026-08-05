//
//  ClipboardCryptoTests.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-08-05.
//

import XCTest
@testable import ClipArc

final class ClipboardCryptoTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(ClipboardCrypto.isAvailable, "Keychain unavailable in this environment")
        try XCTSkipUnless(ClipboardCrypto.isEnabled, "Encryption disabled in this environment")
    }

    // MARK: - Round trip

    func testEncryptDecryptRoundTrip() {
        let plain = "Tr0ub4dor&3 — 密码 🔐"
        let stored = ClipboardCrypto.encrypt(plain)

        XCTAssertNotEqual(stored, plain)
        XCTAssertTrue(ClipboardCrypto.isEncrypted(stored))
        XCTAssertFalse(stored.contains("Tr0ub4dor"))
        XCTAssertEqual(ClipboardCrypto.decrypt(stored), plain)
    }

    func testEncryptionIsNonDeterministic() {
        // AES-GCM uses a fresh nonce, so identical input must not produce identical
        // ciphertext - otherwise the store would leak which entries are duplicates.
        let a = ClipboardCrypto.encrypt("same value")
        let b = ClipboardCrypto.encrypt("same value")
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(ClipboardCrypto.decrypt(a), ClipboardCrypto.decrypt(b))
    }

    func testEncryptIsIdempotent() {
        let once = ClipboardCrypto.encrypt("hello")
        let twice = ClipboardCrypto.encrypt(once)
        XCTAssertEqual(once, twice, "Already-encrypted values must not be double-wrapped")
        XCTAssertEqual(ClipboardCrypto.decrypt(twice), "hello")
    }

    func testLegacyPlaintextPassesThrough() {
        // Rows written by older versions have no envelope and must still be readable.
        XCTAssertEqual(ClipboardCrypto.decrypt("legacy plaintext row"), "legacy plaintext row")
        XCTAssertFalse(ClipboardCrypto.isEncrypted("legacy plaintext row"))
    }

    func testCorruptCiphertextDoesNotLeakOrCrash() {
        let corrupt = "encv1:" + Data("not a real sealed box".utf8).base64EncodedString()
        XCTAssertEqual(ClipboardCrypto.decrypt(corrupt), "", "Undecryptable rows must read as empty, never as raw ciphertext")
    }

    func testEmptyStringIsNotEncrypted() {
        XCTAssertEqual(ClipboardCrypto.encrypt(""), "")
    }

    // MARK: - Digests

    func testDigestIsStableAndDistinguishing() {
        XCTAssertEqual(ClipboardCrypto.digest("Content A"), ClipboardCrypto.digest("Content A"))
        XCTAssertNotEqual(ClipboardCrypto.digest("Content A"), ClipboardCrypto.digest("Content B"))
        XCTAssertEqual(ClipboardCrypto.digest("Content A").count, 64)
    }

    func testDigestIsNotAPlainSHA256OfTheContent() {
        // A bare SHA-256 sitting in the database is a crackable fingerprint of what
        // was copied; the keyed digest must not match one.
        let plainSHA = "02f67ccd1094983cb438874466ce795ddf13ec4989dbd10eebfcf3ab2c8c04ca"  // SHA-256("Content A")
        XCTAssertNotEqual(ClipboardCrypto.digest("Content A"), plainSHA)
    }

    // MARK: - Model integration

    func testItemStoresCiphertextButReadsPlaintext() {
        let secret = "hunter2-Very$ecret"
        let item = ClipboardItem(content: secret, type: .text)

        XCTAssertEqual(item.content, secret, "Callers always see plaintext")
        XCTAssertTrue(item.isStoredEncrypted)
        XCTAssertFalse(item.contentStorage.contains("hunter2"), "The stored column must not hold the secret")
        XCTAssertFalse(item.previewTextStorage.contains("hunter2"))
    }

    func testItemContentSetterReEncrypts() {
        let item = ClipboardItem(content: "first", type: .text)
        item.content = "second value"

        XCTAssertEqual(item.content, "second value")
        XCTAssertTrue(item.isStoredEncrypted)
        XCTAssertFalse(item.contentStorage.contains("second value"))
    }

    func testFileItemEncryptsPathsButStillResolvesURLs() {
        let urls = [URL(fileURLWithPath: "/tmp/secret-contract.pdf")]
        let item = ClipboardItem(fileURLs: urls)

        XCTAssertEqual(item.fileURLs, urls)
        XCTAssertFalse(item.filePathsJSONStorage?.contains("secret-contract") ?? false)
    }

    func testURLTitleIsEncrypted() {
        let item = ClipboardItem(content: "https://example.com", type: .url)
        item.urlTitle = "My Private Dashboard"

        XCTAssertEqual(item.urlTitle, "My Private Dashboard")
        XCTAssertFalse(item.urlTitleStorage?.contains("Private") ?? false)
    }

    func testMaskedSensitiveItemNeverExposesContentAnywhere() {
        let secret = "Xy7!kLm9qRtZ"
        let item = ClipboardItem(content: secret, type: .text)
        item.sensitiveKind = .password

        XCTAssertEqual(item.content, secret, "Paste must still deliver the real value")
        XCTAssertFalse(item.maskedPreview.contains(secret))
        XCTAssertFalse(item.contentStorage.contains(secret))
    }
}
