//
//  ClipboardItemType.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import Foundation

enum ClipboardItemType: String, Codable, CaseIterable {
    case text = "text"
    case url = "url"

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        }
    }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .url: return "URL"
        }
    }
}
