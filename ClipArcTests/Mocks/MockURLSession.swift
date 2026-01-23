//
//  MockURLSession.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-23.
//

import Foundation

/// A mock URLSession for testing network requests
class MockURLSession: @unchecked Sendable {
    var data: Data?
    var response: URLResponse?
    var error: Error?

    var lastRequest: URLRequest?
    var requestCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        requestCount += 1

        if let error = error {
            throw error
        }

        let data = self.data ?? Data()
        let response = self.response ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/html"]
        )!

        return (data, response)
    }

    // MARK: - Convenience Methods

    func setHTMLResponse(_ html: String, statusCode: Int = 200) {
        self.data = html.data(using: .utf8)
        self.response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/html; charset=utf-8"]
        )
    }

    func setJSONResponse(_ json: String, statusCode: Int = 200) {
        self.data = json.data(using: .utf8)
        self.response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
    }

    func setError(_ error: Error) {
        self.error = error
    }

    func reset() {
        data = nil
        response = nil
        error = nil
        lastRequest = nil
        requestCount = 0
    }
}

// MARK: - Mock Errors

enum MockNetworkError: Error {
    case connectionFailed
    case timeout
    case invalidResponse
}
