//
//  Logger.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-23.
//

import Foundation

/// Centralized logging utility that only outputs in DEBUG builds
enum Logger {
    /// Log a debug message with source file information
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The source file (auto-populated)
    ///   - function: The function name (auto-populated)
    static func debug(_ message: String, file: String = #file, function: String = #function) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        print("[\(fileName)] \(message)")
        #endif
    }

    /// Log an error message with source file information
    /// - Parameters:
    ///   - message: The error message to log
    ///   - error: Optional Error object for additional context
    ///   - file: The source file (auto-populated)
    ///   - function: The function name (auto-populated)
    static func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        if let error = error {
            print("[\(fileName)] ERROR: \(message) - \(error.localizedDescription)")
        } else {
            print("[\(fileName)] ERROR: \(message)")
        }
        #endif
    }
}
