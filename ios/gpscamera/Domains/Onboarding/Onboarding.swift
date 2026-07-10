//
//  Onboarding.swift
//  Onboarding - domain constants + default registration (onboarding.md).
//

import Foundation

enum Onboarding {
    /// Persisted true once the first-run flow finishes.
    static let completedKey = "onboarding.completed"

    /// Onboarding has no Settings section, so it registers its one persisted
    /// flag here (the store asserts on unregistered keys). Called at the root.
    static func registerDefaults(_ store: SettingsStore) {
        store.register([completedKey: .bool(false)])
    }
}
