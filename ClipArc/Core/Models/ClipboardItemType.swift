//
//  ClipboardItemType.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import Foundation
import SwiftUI

enum ClipboardItemType: String, Codable, CaseIterable {
    case text = "text"
    case url = "url"
    case image = "image"
    case file = "file"
    case code = "code"
    case color = "color"
    case email = "email"
    case phone = "phone"
    case number = "number"
    case json = "json"
    case other = "other"

    var icon: String {
        switch self {
        case .text: return "doc.text.fill"
        case .url: return "link"
        case .image: return "photo.fill"
        case .file: return "doc.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette.fill"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .number: return "number"
        case .json: return "curlybraces"
        case .other: return "square.on.square"
        }
    }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .url: return "Link"
        case .image: return "Image"
        case .file: return "File"
        case .code: return "Code"
        case .color: return "Color"
        case .email: return "Email"
        case .phone: return "Phone"
        case .number: return "Number"
        case .json: return "JSON"
        case .other: return "Other"
        }
    }

    var accentColor: Color {
        switch self {
        case .text: return .gray
        case .url: return .blue
        case .image: return .purple
        case .file: return .orange
        case .code: return .green
        case .color: return .pink
        case .email: return .red
        case .phone: return .teal
        case .number: return .indigo
        case .json: return .yellow
        case .other: return .secondary
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .text: return [Color(.systemGray).opacity(0.3), Color(.systemGray).opacity(0.1)]
        case .url: return [Color.blue.opacity(0.3), Color.cyan.opacity(0.1)]
        case .image: return [Color.purple.opacity(0.3), Color.pink.opacity(0.1)]
        case .file: return [Color.orange.opacity(0.3), Color.yellow.opacity(0.1)]
        case .code: return [Color.green.opacity(0.3), Color.mint.opacity(0.1)]
        case .color: return [Color.pink.opacity(0.3), Color.red.opacity(0.1)]
        case .email: return [Color.red.opacity(0.3), Color.orange.opacity(0.1)]
        case .phone: return [Color.teal.opacity(0.3), Color.cyan.opacity(0.1)]
        case .number: return [Color.indigo.opacity(0.3), Color.purple.opacity(0.1)]
        case .json: return [Color.yellow.opacity(0.3), Color.orange.opacity(0.1)]
        case .other: return [Color.secondary.opacity(0.2), Color.secondary.opacity(0.05)]
        }
    }
}
