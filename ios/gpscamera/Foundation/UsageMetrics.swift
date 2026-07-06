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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var firstInstalledAt: Date {
        Date(timeIntervalSince1970: defaults.double(forKey: Key.firstInstalledAt))
    }

    var sessionCount: Int { defaults.integer(forKey: Key.sessionCount) }
    var photoCaptureCount: Int { defaults.integer(forKey: Key.photoCaptures) }
    var videoCaptureCount: Int { defaults.integer(forKey: Key.videoCaptures) }

    /// Once per app launch, before any event fires.
    func recordSessionStart() {
        if defaults.object(forKey: Key.firstInstalledAt) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: Key.firstInstalledAt)
        }
        increment(Key.sessionCount)
    }

    func recordPhotoCapture() { increment(Key.photoCaptures) }
    func recordVideoCapture() { increment(Key.videoCaptures) }

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
