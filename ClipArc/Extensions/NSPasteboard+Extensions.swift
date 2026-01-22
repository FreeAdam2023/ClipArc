//
//  NSPasteboard+Extensions.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit

extension NSPasteboard {
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
