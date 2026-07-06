//
//  FirebaseTracker.swift
//  Event - backend adapter (event.md "Backend"): Firebase Analytics +
//  Crashlytics, default SDK config, no IDFA/ATT. Inert until
//  GoogleService-Info.plist ships in the bundle, so the app builds and tests
//  run without it.
//

import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import Foundation

final class FirebaseTracker: EventTracking {
    private let metrics: UsageMetrics
    private let configured: Bool

    init(metrics: UsageMetrics) {
        self.metrics = metrics
        if FirebaseApp.app() == nil,
           Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        configured = FirebaseApp.app() != nil
    }

    func track(_ event: Event) {
        guard configured else { return }
        // Event params win over globals on a name clash.
        var params: [String: Any] = globalParams
        event.params.forEach { params[$0] = $1 }
        Analytics.logEvent(event.name, parameters: params)
    }

    func record(_ error: Error, keys: [String: String]) {
        guard configured else { return }
        let crashlytics = Crashlytics.crashlytics()
        keys.forEach { crashlytics.setCustomValue($1, forKey: $0) }
        crashlytics.record(error: error)
    }

    /// Included in every event (event.md "Event Catalog"); values from
    /// foundation's UsageMetrics.
    private var globalParams: [String: Any] {
        ["first_installed_at": metrics.firstInstalledAt
            .formatted(.iso8601),
         "session_count": metrics.sessionCount,
         "photo_capture_count": metrics.photoCaptureCount,
         "video_capture_count": metrics.videoCaptureCount,
         "is_pro": metrics.isPro()]
    }
}
