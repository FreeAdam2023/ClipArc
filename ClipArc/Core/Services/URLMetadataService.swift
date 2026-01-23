//
//  URLMetadataService.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-22.
//

import Foundation

/// Service for fetching metadata (like page titles) from URLs
actor URLMetadataService {
    static let shared = URLMetadataService()

    private var cache: [String: String] = [:]  // URL -> Title cache
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5  // 5 second timeout
        config.timeoutIntervalForResource = 10
        config.httpMaximumConnectionsPerHost = 2
        self.session = URLSession(configuration: config)
    }

    /// Fetch the page title for a given URL
    /// Returns nil if the URL is invalid, not HTTP(S), or if fetching fails
    func fetchTitle(for urlString: String) async -> String? {
        Logger.debug("fetchTitle called for: \(urlString)")

        // Check cache first
        if let cached = cache[urlString] {
            Logger.debug("Returning cached title: \(cached)")
            return cached
        }

        guard var url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            Logger.debug("Invalid URL or scheme")
            return nil
        }

        // Upgrade HTTP to HTTPS for App Transport Security compliance
        if scheme == "http" {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            if let httpsURL = components?.url {
                url = httpsURL
                Logger.debug("Upgraded to HTTPS: \(url.absoluteString)")
            }
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            // Set a user agent to avoid being blocked
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            // Only accept HTML
            request.setValue("text/html", forHTTPHeaderField: "Accept")

            Logger.debug("Fetching URL...")
            let (data, response) = try await session.data(for: request)
            Logger.debug("Got response, data size: \(data.count) bytes")

            // Check response is HTML
            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.debug("Not an HTTP response")
                return nil
            }

            Logger.debug("Status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                Logger.debug("Non-200 status code")
                return nil
            }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            Logger.debug("Content-Type: \(contentType)")

            guard contentType.contains("text/html") else {
                Logger.debug("Not HTML content")
                return nil
            }

            // Only read first 32KB to find title (optimization)
            let limitedData = data.prefix(32768)

            guard let html = String(data: limitedData, encoding: .utf8) ?? String(data: limitedData, encoding: .isoLatin1) else {
                Logger.debug("Failed to decode HTML")
                return nil
            }

            // Extract title using regex
            if let title = extractTitle(from: html) {
                let cleanedTitle = cleanTitle(title)
                Logger.debug("Extracted title: \(cleanedTitle)")
                cache[urlString] = cleanedTitle
                return cleanedTitle
            }

            Logger.debug("No title found in HTML")
            return nil
        } catch {
            Logger.error("Failed to fetch", error: error)
            return nil
        }
    }

    /// Extract title from HTML content
    private func extractTitle(from html: String) -> String? {
        // Try to find <title>...</title>
        let patterns = [
            "<title[^>]*>([^<]+)</title>",  // Standard title tag
            "<meta[^>]+property=[\"']og:title[\"'][^>]+content=[\"']([^\"']+)[\"']",  // OpenGraph title
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+property=[\"']og:title[\"']",  // OpenGraph title (alternate order)
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let titleRange = Range(match.range(at: 1), in: html) {
                return String(html[titleRange])
            }
        }

        return nil
    }

    /// Clean up the extracted title
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&#x22;", with: "\"")

        // Decode numeric HTML entities
        let numericPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            let matches = regex.matches(in: cleaned, range: range)

            for match in matches.reversed() {
                if let codeRange = Range(match.range(at: 1), in: cleaned),
                   let code = Int(cleaned[codeRange]),
                   let scalar = Unicode.Scalar(code) {
                    let char = String(Character(scalar))
                    if let fullRange = Range(match.range, in: cleaned) {
                        cleaned.replaceSubrange(fullRange, with: char)
                    }
                }
            }
        }

        // Limit length
        if cleaned.count > 100 {
            cleaned = String(cleaned.prefix(97)) + "..."
        }

        return cleaned
    }

    /// Clear the cache
    func clearCache() {
        cache.removeAll()
    }
}
