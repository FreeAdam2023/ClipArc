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
    var content: String
    var typeRaw: String
    var createdAt: Date
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var contentHash: String
    var previewText: String
    var useCount: Int = 0  // Track how many times this item has been pasted
    @Attribute(.externalStorage) var imageData: Data?  // Store image data externally for better performance
    var imageWidth: Int = 0
    var imageHeight: Int = 0
    var filePathsJSON: String?  // Store file paths as JSON array
    var urlTitle: String?  // Page title for URL items (fetched asynchronously)

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
        self.content = content
        self.typeRaw = type.rawValue
        self.createdAt = Date()
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.contentHash = ClipboardItem.computeHash(content)
        self.previewText = ClipboardItem.generatePreview(content)
        self.useCount = 0
        self.imageData = nil
        self.imageWidth = 0
        self.imageHeight = 0
        self.filePathsJSON = nil
        self.urlTitle = nil
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
        self.content = "Image (\(width)×\(height))"
        self.typeRaw = ClipboardItemType.image.rawValue
        self.createdAt = Date()
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.contentHash = ClipboardItem.computeHashFromData(imageData)
        self.previewText = "Image (\(width)×\(height))"
        self.useCount = 0
        self.imageData = imageData
        self.imageWidth = width
        self.imageHeight = height
        self.filePathsJSON = nil
        self.urlTitle = nil
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

        self.content = contentValue
        self.previewText = previewValue
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
        if let jsonData = try? JSONEncoder().encode(paths) {
            self.filePathsJSON = String(data: jsonData, encoding: .utf8)
        } else {
            self.filePathsJSON = nil
        }
        self.urlTitle = nil
    }

    static func computeHash(_ content: String) -> String {
        let data = Data(content.utf8)
        return computeHashFromData(data)
    }

    static func computeHashFromData(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
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

        // Check for file path
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") || trimmed.hasPrefix("file://") {
            let path = trimmed.replacingOccurrences(of: "file://", with: "")
            if FileManager.default.fileExists(atPath: path) {
                return .file
            }
        }

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
