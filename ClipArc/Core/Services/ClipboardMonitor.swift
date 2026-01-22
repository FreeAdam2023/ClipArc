//
//  ClipboardMonitor.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-21.
//

import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardMonitor: ObservableObject {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pollingInterval: TimeInterval = 0.5

    var onNewContent: ((String, ClipboardItemType) -> Void)?

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

        guard let content = extractContent(from: pasteboard) else { return }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let type = ClipboardItemType.detectType(trimmed)
        onNewContent?(trimmed, type)
    }

    private func extractContent(from pasteboard: NSPasteboard) -> String? {
        if let urlString = pasteboard.string(forType: .URL) {
            return urlString
        }

        if let string = pasteboard.string(forType: .string) {
            return string
        }

        return nil
    }

    deinit {
        timer?.invalidate()
    }
}

extension ClipboardItemType {
    static func detectType(_ content: String) -> ClipboardItemType {
        ClipboardItem.detectType(content)
    }
}
