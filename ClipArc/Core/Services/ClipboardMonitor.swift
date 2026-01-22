//
//  ClipboardMonitor.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Combine
import Foundation

/// Represents clipboard content that can be text, image, or files
enum ClipboardContent {
    case text(String, ClipboardItemType)
    case image(Data, width: Int, height: Int)
    case files([URL])  // File URLs
}

@MainActor
final class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pollingInterval: TimeInterval = 0.5

    var onNewContent: ((ClipboardContent) -> Void)?

    @Published private(set) var isMonitoring = false

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }

        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount
        print("[ClipboardMonitor] Pasteboard changed, changeCount: \(currentChangeCount)")

        guard let content = extractContent(from: pasteboard) else {
            print("[ClipboardMonitor] Could not extract content")
            return
        }

        switch content {
        case .text(let text, let type):
            print("[ClipboardMonitor] Detected text (\(type)): \(text.prefix(30))...")
        case .image(let data, let width, let height):
            print("[ClipboardMonitor] Detected image: \(width)x\(height), \(data.count) bytes")
        case .files(let urls):
            print("[ClipboardMonitor] Detected \(urls.count) file(s)")
        }

        onNewContent?(content)
    }

    private func extractContent(from pasteboard: NSPasteboard) -> ClipboardContent? {
        // Check for files first (highest priority)
        if let fileURLs = extractFileURLs(from: pasteboard), !fileURLs.isEmpty {
            return .files(fileURLs)
        }

        // Check for image
        if let imageData = extractImageData(from: pasteboard) {
            return imageData
        }

        // Check for URL
        if let urlString = pasteboard.string(forType: .URL) {
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .text(trimmed, ClipboardItemType.detectType(trimmed))
        }

        // Check for string
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .text(trimmed, ClipboardItemType.detectType(trimmed))
        }

        return nil
    }

    private func extractFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        // Check for file URLs (modern API)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            // Filter to only local file URLs that exist
            let validURLs = urls.filter { url in
                url.isFileURL && FileManager.default.fileExists(atPath: url.path)
            }
            if !validURLs.isEmpty {
                return validURLs
            }
        }

        return nil
    }

    private func extractImageData(from pasteboard: NSPasteboard) -> ClipboardContent? {
        // Supported image types
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]

        for type in imageTypes {
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data) {
                // Convert to PNG for consistent storage
                guard let pngData = image.pngData else { continue }

                let width = Int(image.size.width)
                let height = Int(image.size.height)

                // Skip very small images (likely icons or UI elements)
                guard width > 16 && height > 16 else { continue }

                return .image(pngData, width: width, height: height)
            }
        }

        return nil
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - NSImage Extension

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}

extension ClipboardItemType {
    static func detectType(_ content: String) -> ClipboardItemType {
        ClipboardItem.detectType(content)
    }
}
