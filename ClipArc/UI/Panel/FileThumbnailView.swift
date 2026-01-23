//
//  FileThumbnailView.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-23.
//

import AppKit
import SwiftUI
import QuickLookThumbnailing

struct FileThumbnailView: View {
    let item: ClipboardItem
    let fileURL: URL
    let accentColor: Color
    let fileIconName: String

    @State private var thumbnail: NSImage?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 6) {
            if let thumbnail = thumbnail {
                let imageSize = thumbnail.size
                let aspectRatio = imageSize.width / max(imageSize.height, 1)

                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxWidth: UIConstants.thumbnailWidth, maxHeight: UIConstants.thumbnailHeight)
                    .clipShape(RoundedRectangle(cornerRadius: UIConstants.mediumCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: UIConstants.mediumCornerRadius)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            } else if isLoading {
                RoundedRectangle(cornerRadius: UIConstants.mediumCornerRadius)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 100, height: 80)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.7)
                    )
            } else {
                Image(systemName: fileIconName)
                    .font(.system(size: 40))
                    .foregroundStyle(accentColor)
                    .frame(height: 80)
            }

            Text(fileURL.lastPathComponent)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(fileURL.deletingLastPathComponent().path)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // First check for cached thumbnail
        if let cachedData = item.fileThumbnailData,
           let cachedImage = NSImage(data: cachedData) {
            await MainActor.run {
                self.thumbnail = cachedImage
                self.isLoading = false
            }
            return
        }

        // Try to generate thumbnail (only works if we have file access)
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }

        // Use Quick Look to generate thumbnail
        let size = CGSize(width: UIConstants.thumbnailWidth, height: UIConstants.thumbnailHeight)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let image = representation.nsImage

            // Cache the thumbnail
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                await MainActor.run {
                    item.fileThumbnailData = pngData
                }
            }

            await MainActor.run {
                self.thumbnail = image
                self.isLoading = false
            }
        } catch {
            // Quick Look failed, try direct image loading for image files
            if isImageFile(fileURL), let image = NSImage(contentsOf: fileURL) {
                let scaledImage = createScaledThumbnail(from: image, maxSize: size)

                // Cache the thumbnail
                if let tiffData = scaledImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    await MainActor.run {
                        item.fileThumbnailData = pngData
                    }
                }

                await MainActor.run {
                    self.thumbnail = scaledImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp", "ico", "icns"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    private func createScaledThumbnail(from image: NSImage, maxSize: CGSize) -> NSImage {
        let originalSize = image.size
        let widthRatio = maxSize.width / originalSize.width
        let heightRatio = maxSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio, 1.0)

        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        return thumbnail
    }
}
