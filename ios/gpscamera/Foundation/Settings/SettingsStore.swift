//
//  SettingsStore.swift
//  Foundation - typed settings for each domain (foundation.md).
//

import Combine
import Foundation

extension Notification.Name {
    /// Posted (main thread) the first time an enabled permission-coupled setting
    /// is read while its permission is revoked. userInfo: ["key": String].
    static let settingPermissionMismatch = Notification.Name("settingPermissionMismatch")
    /// Posted (main thread) when the pro entitlement changes so an open
    /// Settings screen re-evaluates its gated rows. Foundation declares the
    /// contract; monetization posts it.
    static let settingsGatingChanged = Notification.Name("settingsGatingChanged")
}

/// Key-value settings backed by UserDefaults. Defaults are registered from the
/// section schemas at composition time; typed reads fall back to them.
/// Thread-safe: capture pipelines read settings off the main actor.
nonisolated final class SettingsStore: ObservableObject {
    /// Composition-root hook, delivered on the main queue after every write
    /// (key, new value). Foundation stays domain-agnostic; the root binds it
    /// to analytics (event.md settings_changed).
    var onSet: ((String, SettingValue) -> Void)?
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var registered: [String: SettingValue] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Called by the registry with every item's key + defaultValue.
    func register(_ defaultValues: [String: SettingValue]) {
        lock.lock(); defer { lock.unlock() }
        registered.merge(defaultValues) { _, new in new }
    }

    // MARK: - Typed access

    func value(_ key: String) -> SettingValue {
        lock.lock()
        guard let def = registered[key] else {
            lock.unlock()
            assertionFailure("unregistered setting key: \(key)")
            return .bool(false)
        }
        lock.unlock()
        return SettingValue.from(defaults.object(forKey: key), like: def) ?? def
    }

    func set(_ value: SettingValue, for key: String) {
        publishChange()
        defaults.set(value.primitive, forKey: key)
        if let onSet { DispatchQueue.main.async { onSet(key, value) } }
    }

    /// Runs `action` on the main queue after any setting write lands.
    /// (objectWillChange fires pre-write; the queue hop defers delivery until
    /// the new value is readable.) Retain the returned cancellable.
    func onChange(_ action: @escaping () -> Void) -> AnyCancellable {
        objectWillChange.sink { DispatchQueue.main.async(execute: action) }
    }

    func bool(_ key: String) -> Bool { value(key).boolValue }
    func string(_ key: String) -> String { value(key).stringValue }
    func number(_ key: String) -> Double { value(key).numberValue }
    func stringList(_ key: String) -> [String] { value(key).stringListValue }

    // MARK: - Permission-coupled reads (foundation.md)

    /// Effective value of an on/off item that depends on an OS permission:
    /// on && !denied. On the first read after a granted permission is revoked,
    /// posts `.settingPermissionMismatch` (non-blocking; caller skips the feature).
    /// `notDetermined` passes through: the feature's own request runs lazily.
    func effectiveBool(_ key: String, permission: SettingPermission) -> Bool {
        let enabled = bool(key)
        switch SettingsPermissions.status(permission) {
        case .authorized:
            markGranted(key)
            return enabled
        case .notDetermined:
            return enabled
        case .denied:
            if enabled, wasGranted(key), !mismatchReported(key) {
                setMismatchReported(key)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .settingPermissionMismatch,
                                                    object: nil, userInfo: ["key": key])
                }
            }
            return false
        }
    }

    /// Bookkeeping for the mismatch popup: it shows only when the permission
    /// was granted once and later revoked, and only once per revocation.
    private func wasGranted(_ key: String) -> Bool {
        defaults.bool(forKey: "granted." + key)
    }

    private func markGranted(_ key: String) {
        if !defaults.bool(forKey: "granted." + key) {
            defaults.set(true, forKey: "granted." + key)
        }
        if defaults.bool(forKey: "mismatch." + key) {
            defaults.set(false, forKey: "mismatch." + key)   // re-granted: re-arm
        }
    }

    private func mismatchReported(_ key: String) -> Bool {
        defaults.bool(forKey: "mismatch." + key)
    }

    private func setMismatchReported(_ key: String) {
        defaults.set(true, forKey: "mismatch." + key)
    }

    private func publishChange() {
        if Thread.isMainThread {
            objectWillChange.send()
        } else {
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
}
