//
//  MockUserDefaults.swift
//  ClipArcTests
//
//  Created by Adam Lyu on 2026-01-23.
//

import Foundation

/// A mock UserDefaults for testing without persisting to disk
class MockUserDefaults: UserDefaults {
    private var storage: [String: Any] = [:]

    override init?(suiteName: String?) {
        super.init(suiteName: nil)
    }

    override func object(forKey defaultName: String) -> Any? {
        return storage[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        storage[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
    }

    override func string(forKey defaultName: String) -> String? {
        return storage[defaultName] as? String
    }

    override func integer(forKey defaultName: String) -> Int {
        return storage[defaultName] as? Int ?? 0
    }

    override func bool(forKey defaultName: String) -> Bool {
        return storage[defaultName] as? Bool ?? false
    }

    override func double(forKey defaultName: String) -> Double {
        return storage[defaultName] as? Double ?? 0.0
    }

    override func data(forKey defaultName: String) -> Data? {
        return storage[defaultName] as? Data
    }

    override func array(forKey defaultName: String) -> [Any]? {
        return storage[defaultName] as? [Any]
    }

    override func dictionary(forKey defaultName: String) -> [String: Any]? {
        return storage[defaultName] as? [String: Any]
    }

    override func register(defaults registrationDictionary: [String: Any]) {
        for (key, value) in registrationDictionary {
            if storage[key] == nil {
                storage[key] = value
            }
        }
    }

    override func synchronize() -> Bool {
        return true
    }

    // MARK: - Test Helpers

    func reset() {
        storage.removeAll()
    }

    func allKeys() -> [String] {
        return Array(storage.keys)
    }

    func allValues() -> [Any] {
        return Array(storage.values)
    }

    func contains(key: String) -> Bool {
        return storage[key] != nil
    }
}
