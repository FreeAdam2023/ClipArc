//
//  ClipboardCrypto.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-08-05.
//
//  Encrypts clipboard text at rest so the SwiftData store on disk is useless
//  without the key, which lives in the login Keychain and never leaves this Mac.
//
//  Stored strings use a tagged envelope ("encv1:<base64>"). Anything without the
//  tag is treated as legacy plaintext and passed through unchanged, so histories
//  written by older versions keep working while they are migrated.
//

import CryptoKit
import Foundation
import Security

extension Notification.Name {
    /// Posted when the user switches encryption on, so existing rows get converted.
    static let encryptExistingHistory = Notification.Name("encryptExistingHistory")
}

enum ClipboardCrypto {

    /// Marks a stored string as ciphertext. Version prefixed so the format can change later.
    private static let envelopePrefix = "encv1:"

    private static let keychainService = "com.versegates.ClipArc"
    private static let keychainAccount = "history-encryption-key"

    // MARK: - Key material

    /// Guards `cachedKey`; the model layer touches this from more than one context.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cachedKey: SymmetricKey?
    nonisolated(unsafe) private static var keyLookupFailed = false

    /// Decrypting the same value repeatedly (search filters on every keystroke)
    /// would be wasteful, so results are memoised by ciphertext.
    private static let plaintextCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 2000
        return cache
    }()

    /// False when the Keychain is unreachable. Callers then store plaintext rather
    /// than losing the user's history outright.
    static var isAvailable: Bool { key() != nil }

    /// User setting, read straight from UserDefaults so the model layer can consult
    /// it without hopping to the main actor. Defaults to on.
    static let settingsKey = "encryptHistory"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: settingsKey) as? Bool ?? true
    }

    private static func key() -> SymmetricKey? {
        lock.lock()
        defer { lock.unlock() }

        if let cachedKey { return cachedKey }
        if keyLookupFailed { return nil }

        if let existing = readKeyFromKeychain() {
            cachedKey = existing
            return existing
        }

        let newKey = SymmetricKey(size: .bits256)
        guard storeKeyInKeychain(newKey) else {
            Logger.error("Could not store the history encryption key; content will be saved unencrypted")
            keyLookupFailed = true
            return nil
        }
        cachedKey = newKey
        return newKey
    }

    private static func readKeyFromKeychain() -> SymmetricKey? {
        // Try the data-protection keychain first, then the login keychain, matching
        // the two places `storeKeyInKeychain` may have written to.
        for useDataProtection in [true, false] {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainAccount,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            if useDataProtection {
                query[kSecUseDataProtectionKeychain as String] = true
            }

            var result: CFTypeRef?
            if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
               let data = result as? Data, data.count == 32 {
                return SymmetricKey(data: data)
            }
        }
        return nil
    }

    private static func storeKeyInKeychain(_ key: SymmetricKey) -> Bool {
        let keyData = key.withUnsafeBytes { Data($0) }
        var attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecUseDataProtectionKeychain as String: true,
            // The key must not sync to iCloud or travel to another Mac.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: keyData,
        ]

        SecItemDelete(attributes as CFDictionary)
        var status = SecItemAdd(attributes as CFDictionary, nil)

        // The data-protection keychain needs an application-identifier entitlement,
        // which unsigned/ad-hoc builds and the test host do not have. Fall back to
        // the file-based login keychain there rather than storing content in the clear.
        if status == errSecMissingEntitlement || status == errSecNotAvailable {
            attributes.removeValue(forKey: kSecUseDataProtectionKeychain as String)
            attributes.removeValue(forKey: kSecAttrAccessible as String)
            SecItemDelete(attributes as CFDictionary)
            status = SecItemAdd(attributes as CFDictionary, nil)
        }

        if status != errSecSuccess {
            Logger.error("Keychain write for the history key failed with status \(status)")
        }
        return status == errSecSuccess
    }

    // MARK: - String encryption

    static func isEncrypted(_ stored: String) -> Bool {
        stored.hasPrefix(envelopePrefix)
    }

    /// Encrypts `plain` for storage. Returns it unchanged if encryption is off or unavailable,
    /// so the caller can always store whatever comes back.
    static func encrypt(_ plain: String) -> String {
        guard isEnabled, !plain.isEmpty, !isEncrypted(plain), let key = key() else { return plain }

        do {
            let sealed = try AES.GCM.seal(Data(plain.utf8), using: key)
            guard let combined = sealed.combined else { return plain }
            let envelope = envelopePrefix + combined.base64EncodedString()
            plaintextCache.setObject(plain as NSString, forKey: envelope as NSString)
            return envelope
        } catch {
            Logger.error("Failed to encrypt clipboard content", error: error)
            return plain
        }
    }

    /// Decrypts a stored string. Legacy plaintext passes through untouched.
    /// Returns an empty string if the value cannot be decrypted (for example after
    /// the Keychain key was lost), rather than surfacing ciphertext to the user.
    static func decrypt(_ stored: String) -> String {
        guard isEncrypted(stored) else { return stored }

        if let cached = plaintextCache.object(forKey: stored as NSString) {
            return cached as String
        }

        guard let key = key(),
              let combined = Data(base64Encoded: String(stored.dropFirst(envelopePrefix.count))) else {
            return ""
        }

        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let plain = String(decoding: try AES.GCM.open(box, using: key), as: UTF8.self)
            plaintextCache.setObject(plain as NSString, forKey: stored as NSString)
            return plain
        } catch {
            Logger.error("Failed to decrypt clipboard content", error: error)
            return ""
        }
    }

    /// Optional variant for fields that may be absent.
    static func encryptOptional(_ plain: String?) -> String? {
        guard let plain else { return nil }
        return encrypt(plain)
    }

    static func decryptOptional(_ stored: String?) -> String? {
        guard let stored else { return nil }
        return decrypt(stored)
    }

    // MARK: - Digests

    /// Keyed digest used for de-duplication. A plain SHA-256 of the content would
    /// sit in the database as a crackable fingerprint of what was copied; an HMAC
    /// is meaningless without the Keychain key while still comparing equal.
    static func digest(_ plain: String) -> String {
        guard let key = key() else {
            return SHA256.hash(data: Data(plain.utf8)).hexString
        }
        let mac = HMAC<SHA256>.authenticationCode(for: Data(plain.utf8), using: key)
        return Data(mac).hexString
    }

    static func digest(_ data: Data) -> String {
        guard let key = key() else {
            return SHA256.hash(data: data).hexString
        }
        return Data(HMAC<SHA256>.authenticationCode(for: data, using: key)).hexString
    }

    /// Test seam: forget the in-process key and cached plaintext.
    static func resetCachesForTesting() {
        lock.lock()
        cachedKey = nil
        keyLookupFailed = false
        lock.unlock()
        plaintextCache.removeAllObjects()
    }
}

private extension Sequence where Element == UInt8 {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
