//
//  ScreenshotMonitor.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-30.
//
//  Monitors screenshot folder and auto-adds new screenshots to clipboard history

import AppKit
import Foundation

@MainActor
@Observable
final class ScreenshotMonitor {
    static let shared = ScreenshotMonitor()

    // MARK: - State

    /// Whether screenshot monitoring is enabled
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "screenshotMonitorEnabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "screenshotMonitorEnabled")
            if newValue {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    /// The monitored folder path (for display)
    var monitoredFolderPath: String? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "screenshotFolderBookmark"),
              let url = resolveBookmark(bookmarkData) else {
            return nil
        }
        return url.path
    }

    /// Whether we have a valid folder selected
    var hasFolderSelected: Bool {
        monitoredFolderPath != nil
    }

    // MARK: - Private

    private var folderMonitor: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: Int32 = -1
    private var lastKnownFiles: Set<String> = []
    private var monitoredURL: URL?

    /// Callback when new screenshot is detected
    var onNewScreenshot: ((Data, Int, Int) -> Void)?

    // MARK: - Public API

    /// Let user select screenshot folder
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Screenshot Folder"
        panel.message = "Choose the folder where your screenshots are saved (usually Desktop)"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        // Start at Desktop by default
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }

            Task { @MainActor in
                self?.saveBookmark(for: url)
                self?.startMonitoring()
            }
        }
    }

    /// Remove folder access
    func removeFolder() {
        stopMonitoring()
        UserDefaults.standard.removeObject(forKey: "screenshotFolderBookmark")
        isEnabled = false
    }

    /// Start monitoring (called on app launch if enabled)
    func startMonitoringIfEnabled() {
        if isEnabled && hasFolderSelected {
            startMonitoring()
        }
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "screenshotFolderBookmark"),
              let url = resolveBookmark(bookmarkData) else {
            Logger.debug("ScreenshotMonitor: No valid bookmark found")
            return
        }

        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            Logger.debug("ScreenshotMonitor: Failed to access security-scoped resource")
            return
        }

        monitoredURL = url

        // Get initial file list
        lastKnownFiles = getFilesInDirectory(url)

        // Open directory for monitoring
        directoryFileDescriptor = open(url.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else {
            Logger.debug("ScreenshotMonitor: Failed to open directory")
            url.stopAccessingSecurityScopedResource()
            return
        }

        // Create dispatch source for file system events
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.handleDirectoryChange()
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.directoryFileDescriptor >= 0 {
                close(self.directoryFileDescriptor)
                self.directoryFileDescriptor = -1
            }
            self.monitoredURL?.stopAccessingSecurityScopedResource()
        }

        source.resume()
        folderMonitor = source

        Logger.debug("ScreenshotMonitor: Started monitoring \(url.path)")
    }

    private func stopMonitoring() {
        folderMonitor?.cancel()
        folderMonitor = nil
        lastKnownFiles.removeAll()
        Logger.debug("ScreenshotMonitor: Stopped monitoring")
    }

    private func handleDirectoryChange() {
        guard let url = monitoredURL else { return }

        let currentFiles = getFilesInDirectory(url)
        let newFiles = currentFiles.subtracting(lastKnownFiles)

        for fileName in newFiles {
            let fileURL = url.appendingPathComponent(fileName)

            // Check if it's a screenshot (PNG or JPG, starts with "Screenshot" or localized equivalent)
            if isScreenshotFile(fileURL) {
                // Small delay to ensure file is fully written
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.processScreenshot(at: fileURL)
                }
            }
        }

        lastKnownFiles = currentFiles
    }

    private func isScreenshotFile(_ url: URL) -> Bool {
        let fileName = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        // Check extension
        guard ["png", "jpg", "jpeg"].contains(ext) else { return false }

        // Check common screenshot naming patterns (localized)
        let screenshotPrefixes = [
            "screenshot",       // English
            "截屏",             // Chinese
            "截图",             // Chinese
            "スクリーンショット",  // Japanese
            "bildschirmfoto",   // German
            "capture d'écran",  // French
            "captura de pantalla" // Spanish
        ]

        for prefix in screenshotPrefixes {
            if fileName.hasPrefix(prefix) {
                return true
            }
        }

        // Also check for CleanShot, Snagit, etc. common screenshot tools
        let toolPrefixes = ["cleanshot", "snagit", "skitch"]
        for prefix in toolPrefixes {
            if fileName.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    private func processScreenshot(at url: URL) {
        guard let image = NSImage(contentsOf: url),
              let pngData = image.pngData else {
            Logger.debug("ScreenshotMonitor: Failed to load image from \(url.path)")
            return
        }

        let width = Int(image.size.width)
        let height = Int(image.size.height)

        Logger.debug("ScreenshotMonitor: New screenshot detected: \(url.lastPathComponent) (\(width)x\(height))")

        onNewScreenshot?(pngData, width, height)
    }

    private func getFilesInDirectory(_ url: URL) -> Set<String> {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            return []
        }
        return Set(contents)
    }

    // MARK: - Bookmark Management

    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmarkData, forKey: "screenshotFolderBookmark")
            Logger.debug("ScreenshotMonitor: Saved bookmark for \(url.path)")
        } catch {
            Logger.debug("ScreenshotMonitor: Failed to save bookmark: \(error)")
        }
    }

    private func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Re-save the bookmark
                saveBookmark(for: url)
            }

            return url
        } catch {
            Logger.debug("ScreenshotMonitor: Failed to resolve bookmark: \(error)")
            return nil
        }
    }

    // MARK: - Init

    private init() {}
}
