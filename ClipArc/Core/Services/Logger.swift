//
//  Logger.swift
//  ClipArc
//
//  Created by Adam Lyu on 2026-01-23.
//

import Foundation
import os

/// Centralized logging utility.
/// - Writes to Apple's unified log system (visible via `log show --predicate 'subsystem == "com.versegates.ClipArc"'`).
/// - In DEBUG also mirrors to stdout for Xcode console.
enum Logger {
    private static let subsystem = "com.versegates.ClipArc"

    private static func osLogger(category: String) -> os.Logger {
        os.Logger(subsystem: subsystem, category: category)
    }

    private static func category(from file: String) -> String {
        (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
    }

    /// Debug-level log. Not persisted to disk by the unified log system unless explicitly enabled.
    static func debug(_ message: String, file: String = #file, function: String = #function) {
        let cat = category(from: file)
        osLogger(category: cat).debug("\(message, privacy: .public)")
        #if DEBUG
        print("[\(cat)] \(message)")
        #endif
    }

    /// Info-level log. Persisted briefly; use for routine state changes.
    static func info(_ message: String, file: String = #file, function: String = #function) {
        let cat = category(from: file)
        osLogger(category: cat).info("\(message, privacy: .public)")
        #if DEBUG
        print("[\(cat)] INFO: \(message)")
        #endif
    }

    /// Notice-level log. Always persisted to disk. Use for lifecycle events
    /// (launch, terminate, window close) that we need to inspect post-mortem.
    static func notice(_ message: String, file: String = #file, function: String = #function) {
        let cat = category(from: file)
        osLogger(category: cat).notice("\(message, privacy: .public)")
        #if DEBUG
        print("[\(cat)] NOTICE: \(message)")
        #endif
    }

    /// Error-level log. Always persisted.
    static func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function) {
        let cat = category(from: file)
        let logger = osLogger(category: cat)
        if let error = error {
            logger.error("\(message, privacy: .public) - \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
        #if DEBUG
        if let error = error {
            print("[\(cat)] ERROR: \(message) - \(error.localizedDescription)")
        } else {
            print("[\(cat)] ERROR: \(message)")
        }
        #endif
    }

    /// Fault-level log. Highest severity, always persisted. For unrecoverable conditions.
    static func fault(_ message: String, error: Error? = nil, file: String = #file, function: String = #function) {
        let cat = category(from: file)
        let logger = osLogger(category: cat)
        if let error = error {
            logger.fault("\(message, privacy: .public) - \(error.localizedDescription, privacy: .public)")
        } else {
            logger.fault("\(message, privacy: .public)")
        }
        #if DEBUG
        if let error = error {
            print("[\(cat)] FAULT: \(message) - \(error.localizedDescription)")
        } else {
            print("[\(cat)] FAULT: \(message)")
        }
        #endif
    }
}
