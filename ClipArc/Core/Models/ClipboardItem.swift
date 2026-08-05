//
//  ClipboardItem.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import Foundation
import SwiftData
import CryptoKit

@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var createdAt: Date
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var contentHash: String
    var useCount: Int = 0  // Track how many times this item has been pasted
    @Attribute(.externalStorage) var imageData: Data?  // Store image data externally for better performance
    var imageWidth: Int = 0
    var imageHeight: Int = 0
    @Attribute(.externalStorage) var fileThumbnailData: Data?  // Cached thumbnail for file items
    var sensitiveKindRaw: String?  // Set when the content looks like a credential / personal data

    // MARK: - Encrypted-at-rest storage
    //
    // These hold ciphertext (or legacy plaintext written by older versions).
    // `originalName` keeps SwiftData's lightweight migration pointed at the old
    // columns, so existing histories are read back without a custom migration plan.
    // Always go through the plaintext accessors below - never read these directly.

    @Attribute(originalName: "content") var contentStorage: String
    @Attribute(originalName: "previewText") var previewTextStorage: String
    @Attribute(originalName: "filePathsJSON") var filePathsJSONStorage: String?
    @Attribute(originalName: "urlTitle") var urlTitleStorage: String?

    /// The clipboard payload, decrypted. This is what gets displayed, searched and pasted.
    var content: String {
        get { ClipboardCrypto.decrypt(contentStorage) }
        set { contentStorage = ClipboardCrypto.encrypt(newValue) }
    }

    var previewText: String {
        get { ClipboardCrypto.decrypt(previewTextStorage) }
        set { previewTextStorage = ClipboardCrypto.encrypt(newValue) }
    }

    /// Page title for URL items (fetched asynchronously)
    var urlTitle: String? {
        get { ClipboardCrypto.decryptOptional(urlTitleStorage) }
        set { urlTitleStorage = ClipboardCrypto.encryptOptional(newValue) }
    }

    /// File paths as a JSON array
    var filePathsJSON: String? {
        get { ClipboardCrypto.decryptOptional(filePathsJSONStorage) }
        set { filePathsJSONStorage = ClipboardCrypto.encryptOptional(newValue) }
    }

    /// True once the stored columns hold ciphertext rather than legacy plaintext.
    var isStoredEncrypted: Bool {
        ClipboardCrypto.isEncrypted(contentStorage)
    }

    /// Get file URLs from stored JSON
    var fileURLs: [URL] {
        guard let json = filePathsJSON,
              let data = json.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return paths.map { URL(fileURLWithPath: $0) }
    }

    var type: ClipboardItemType {
        get { ClipboardItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    /// Kind of sensitive content this item holds, if any.
    var sensitiveKind: SensitiveKind? {
        get { sensitiveKindRaw.flatMap { SensitiveKind(rawValue: $0) } }
        set { sensitiveKindRaw = newValue?.rawValue }
    }

    var isSensitive: Bool { sensitiveKindRaw != nil }

    /// Redacted stand-in for `previewText`. Display only — `content` stays intact,
    /// so copying and pasting are never affected.
    var maskedPreview: String {
        guard let kind = sensitiveKind else { return previewText }
        return SensitiveMask.mask(content, kind: kind)
    }

    /// Whether this item is considered "frequent" (used 3+ times)
    var isFrequent: Bool {
        useCount >= 3
    }

    init(
        content: String,
        type: ClipboardItemType,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.id = UUID()
        // Stored columns are written through the crypto layer directly: computed
        // accessors are not usable until every stored property is initialised.
        self.contentStorage = ClipboardCrypto.encrypt(content)
        self.typeRaw = type.rawValue
        self.createdAt = Date()
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.contentHash = ClipboardItem.computeHash(content)
        self.previewTextStorage = ClipboardCrypto.encrypt(ClipboardItem.generatePreview(content))
        self.useCount = 0
        self.imageData = nil
        self.imageWidth = 0
        self.imageHeight = 0
        self.filePathsJSONStorage = nil
        self.urlTitleStorage = nil
        self.fileThumbnailData = nil
        self.sensitiveKindRaw = nil
    }

    /// Initialize with image data
    init(
        imageData: Data,
        width: Int,
        height: Int,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.id = UUID()
        let label = "Image (\(width)×\(height))"
        self.contentStorage = ClipboardCrypto.encrypt(label)
        self.typeRaw = ClipboardItemType.image.rawValue
        self.createdAt = Date()
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.contentHash = ClipboardItem.computeHashFromData(imageData)
        self.previewTextStorage = ClipboardCrypto.encrypt(label)
        self.useCount = 0
        self.imageData = imageData
        self.imageWidth = width
        self.imageHeight = height
        self.filePathsJSONStorage = nil
        self.urlTitleStorage = nil
        self.fileThumbnailData = nil
        self.sensitiveKindRaw = nil
    }

    /// Initialize with file URLs
    init(
        fileURLs: [URL],
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.id = UUID()

        // Generate display content (use local variables first)
        let fileNames = fileURLs.map { $0.lastPathComponent }
        let contentValue: String
        let previewValue: String

        if fileURLs.count == 1 {
            contentValue = fileURLs[0].path
            previewValue = fileNames[0]
        } else {
            contentValue = fileURLs.map { $0.path }.joined(separator: "\n")
            previewValue = "\(fileURLs.count) files: " + fileNames.prefix(3).joined(separator: ", ") + (fileURLs.count > 3 ? "..." : "")
        }

        self.contentStorage = ClipboardCrypto.encrypt(contentValue)
        self.previewTextStorage = ClipboardCrypto.encrypt(previewValue)
        self.typeRaw = ClipboardItemType.file.rawValue
        self.createdAt = Date()
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.contentHash = ClipboardItem.computeHash(contentValue)
        self.useCount = 0
        self.imageData = nil
        self.imageWidth = 0
        self.imageHeight = 0

        // Store file paths as JSON
        let paths = fileURLs.map { $0.path }
        if let jsonData = try? JSONEncoder().encode(paths),
           let json = String(data: jsonData, encoding: .utf8) {
            self.filePathsJSONStorage = ClipboardCrypto.encrypt(json)
        } else {
            self.filePathsJSONStorage = nil
        }
        self.urlTitleStorage = nil
        self.fileThumbnailData = nil
        self.sensitiveKindRaw = nil
    }

    /// De-duplication digest. Keyed by the Keychain key when encryption is on, so
    /// the stored value is not a crackable fingerprint of what was copied.
    static func computeHash(_ content: String) -> String {
        ClipboardCrypto.digest(content)
    }

    static func computeHashFromData(_ data: Data) -> String {
        ClipboardCrypto.digest(data)
    }

    static func generatePreview(_ content: String, maxLength: Int = 200) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
        let firstLines = lines.prefix(5).joined(separator: "\n")

        if firstLines.count <= maxLength {
            return firstLines
        }
        return String(firstLines.prefix(maxLength - 3)) + "..."
    }

    static func detectType(_ content: String) -> ClipboardItemType {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check for email
        let emailPattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        if let regex = try? NSRegularExpression(pattern: emailPattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return .email
        }

        // Check for phone number (various formats)
        let phonePattern = "^[+]?[(]?[0-9]{1,4}[)]?[-\\s./0-9]{6,}$"
        if let regex = try? NSRegularExpression(pattern: phonePattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            // Additional check: should have at least 7 digits
            let digitsOnly = trimmed.filter { $0.isNumber }
            if digitsOnly.count >= 7 && digitsOnly.count <= 15 {
                return .phone
            }
        }

        // Check for URL
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "ftp", "file"].contains(scheme) {
            return .url
        }

        // Note: File detection is handled by extractFileURLs in ClipboardMonitor
        // Text that looks like a file path should remain as text type

        // Check for hex color
        let hexColorPattern = "^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$"
        if let regex = try? NSRegularExpression(pattern: hexColorPattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return .color
        }

        // Check for RGB color
        if trimmed.lowercased().hasPrefix("rgb(") || trimmed.lowercased().hasPrefix("rgba(") ||
           trimmed.lowercased().hasPrefix("hsl(") || trimmed.lowercased().hasPrefix("hsla(") {
            return .color
        }

        // Check for JSON
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let data = trimmed.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return .json
            }
        }

        // Check for pure number (including decimals, negative, currency)
        let numberPattern = "^-?[$€¥£]?[0-9]{1,3}(,?[0-9]{3})*(\\.[0-9]+)?%?$"
        if let regex = try? NSRegularExpression(pattern: numberPattern),
           regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
            return .number
        }

        // Check for code patterns
        let codePatterns = [
            "func ", "class ", "struct ", "enum ", "import ",  // Swift
            "var ", "let ", "guard ", "@", "try ", "catch {",  // Swift additional
            "extension ", "protocol ", "typealias ", ".self",  // Swift types
            "function ", "const ", "=> {", "export ",          // JavaScript
            "def ", "if __name__", "from ",                    // Python
            "public class", "private ", "protected ", "void ", // Java/C#
            "<?php", "<?=",                                     // PHP
            "<html", "<!DOCTYPE", "<head", "<body",            // HTML
            "SELECT ", "INSERT ", "UPDATE ", "DELETE ",        // SQL
            "#include", "#define", "int main",                 // C/C++
        ]

        for pattern in codePatterns {
            if trimmed.contains(pattern) {
                return .code
            }
        }

        // Check if it looks like code (has common code syntax)
        let codeIndicators = [
            "() {", "();", "-> ", "=> ", "== ", "!= ", "&&", "||",
            "if (", "for (", "while (", "switch (", "return ",
            "= {", "do {", "} catch", ": [", "]()", "{ get", "{ set",  // Swift closures/blocks
            "fatalError(", "print(", "guard let", "if let",           // Swift common
        ]
        var codeScore = 0
        for indicator in codeIndicators {
            if trimmed.contains(indicator) {
                codeScore += 1
            }
        }
        if codeScore >= 2 {
            return .code
        }

        // Default to text for normal content
        // Use "other" only for very unusual content (binary-like, excessive special chars)
        let alphanumericRatio = Double(trimmed.filter { $0.isLetter || $0.isNumber || $0.isWhitespace }.count) / Double(max(trimmed.count, 1))
        if alphanumericRatio < 0.5 && trimmed.count > 10 {
            return .other
        }

        return .text
    }
}
