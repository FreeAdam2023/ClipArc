//
//  NSPasteboard+Extensions.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit

extension NSPasteboard {
    /// Markers apps use to say "this copy is a secret / not meant to be kept".
    /// Password managers set these when they put a credential on the pasteboard.
    private static let privateContentTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "de.petermaurer.TransientPasteboardType",
        "com.agilebits.onepassword",
    ]

    /// True when the source app flagged this content as concealed or transient,
    /// meaning it should not be stored in clipboard history.
    var isPrivateContent: Bool {
        guard let types = types else { return false }
        return types.contains { Self.privateContentTypes.contains($0.rawValue) }
    }

    var availableTypeDescriptions: [String] {
        return types?.map { $0.rawValue } ?? []
    }

    var hasStringContent: Bool {
        return types?.contains(.string) ?? false
    }

    var hasURLContent: Bool {
        return types?.contains(.URL) ?? false
    }

    func safeString() -> String? {
        return string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func safeURL() -> URL? {
        if let urlString = string(forType: .URL) {
            return URL(string: urlString)
        }
        return nil
    }
}
