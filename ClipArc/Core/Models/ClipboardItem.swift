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

    var type: ClipboardItemType {
        get { ClipboardItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
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
    }

    static func computeHash(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func generatePreview(_ content: String, maxLength: Int = 100) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
        let firstTwoLines = lines.prefix(2).joined(separator: " ")

        if firstTwoLines.count <= maxLength {
            return firstTwoLines
        }
        return String(firstTwoLines.prefix(maxLength - 3)) + "..."
    }

    static func detectType(_ content: String) -> ClipboardItemType {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "ftp", "file"].contains(scheme) {
            return .url
        }
        return .text
    }
}
