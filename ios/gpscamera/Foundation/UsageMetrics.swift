//
//  UsageMetrics.swift
//  Foundation - lightweight usage counters (foundation.md "Usage Metrics").
//  Persisted in UserDefaults. Read by event (global params) and monetization
//  (ad triggers, nudge rules).
//

import Foundation

final class UsageMetrics {
    private let defaults: UserDefaults
    /// Foundation never imports a domain: the composition root binds this to
    /// monetization's live entitlement.
    var isPro: () -> Bool = { false }
    /// Fires after every recorded capture (photo or video); the root binds it
    /// to monetization's nudge orchestrator (foundation.md "Usage Metrics").
    var onCapture: () -> Void = {}

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var firstInstalledAt: Date {
        Date(timeIntervalSince1970: defaults.double(forKey: Key.firstInstalledAt))
    }

    /// Setters exist only for the debug surface's manual edit; production
    /// code mutates through record*().
    var sessionCount: Int {
        get { defaults.integer(forKey: Key.sessionCount) }
        set { defaults.set(newValue, forKey: Key.sessionCount) }
    }
    var photoCaptureCount: Int {
        get { defaults.integer(forKey: Key.photoCaptures) }
        set { defaults.set(newValue, forKey: Key.photoCaptures) }
    }
    var videoCaptureCount: Int {
        get { defaults.integer(forKey: Key.videoCaptures) }
        set { defaults.set(newValue, forKey: Key.videoCaptures) }
    }

    /// This-session counters: in-memory, reset every launch.
    var sessionPhotoCount = 0
    var sessionVideoCount = 0

    /// Once per app launch, before any event fires.
    func recordSessionStart() {
        if defaults.object(forKey: Key.firstInstalledAt) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: Key.firstInstalledAt)
        }
        increment(Key.sessionCount)
    }

    func recordPhotoCapture() {
        increment(Key.photoCaptures)
        sessionPhotoCount += 1
        onCapture()
    }

    func recordVideoCapture() {
        increment(Key.videoCaptures)
        sessionVideoCount += 1
        onCapture()
    }

    private func increment(_ key: String) {
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    private enum Key {
        static let firstInstalledAt = "metrics.firstInstalledAt"
        static let sessionCount = "metrics.sessionCount"
        static let photoCaptures = "metrics.photoCaptureCount"
        static let videoCaptures = "metrics.videoCaptureCount"
    }
}
