//
//  EventValueTests.swift
//  Pure value-type logic for the event domain: name/params mapping.
//

import Foundation
import Testing
@testable import gpscamera

struct EventCatalogTests {
    @Test func namesFollowTheCatalog() {
        #expect(Event.captureCompleted(kind: .photo).name == "capture_completed")
        #expect(Event.captureFailed(kind: .video, reason: "x").name == "capture_failed")
        #expect(Event.galleryOpened.name == "gallery_opened")
        #expect(Event.shared.name == "shared")
        #expect(Event.paywallShown(source: .mainBanner).name == "paywall_shown")
        #expect(Event.purchaseCompleted(product: "p").name == "purchase_completed")
        #expect(Event.purchaseFailed(product: "p", reason: "x").name == "purchase_failed")
        #expect(Event.settingsChanged(key: "k", value: "v").name == "settings_changed")
    }

    @Test func paramsCarryTheTypedValues() {
        #expect(Event.captureCompleted(kind: .video).params == ["kind": "video"])
        #expect(Event.captureFailed(kind: .photo, reason: "d:1").params
                == ["kind": "photo", "reason": "d:1"])
        #expect(Event.galleryOpened.params.isEmpty)
        #expect(Event.paywallShown(source: .settingsBanner).params
                == ["source": "settings_banner"])
        #expect(Event.settingsChanged(key: "camera.photo.format", value: "heic").params
                == ["key": "camera.photo.format", "value": "heic"])
    }

    @Test func reasonIsCompactDomainAndCode() {
        let error = NSError(domain: "AVFoundationErrorDomain", code: -11800)
        #expect(Event.reason(error) == "AVFoundationErrorDomain:-11800")
    }
}

struct UsageMetricsTests {
    @Test func countersPersistAndIncrement() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let metrics = UsageMetrics(defaults: defaults)

        metrics.recordSessionStart()
        let installedAt = metrics.firstInstalledAt
        metrics.recordSessionStart()
        metrics.recordPhotoCapture()
        metrics.recordPhotoCapture()
        metrics.recordVideoCapture()

        #expect(metrics.sessionCount == 2)
        #expect(metrics.firstInstalledAt == installedAt)   // stamped once
        #expect(metrics.photoCaptureCount == 2)
        #expect(metrics.videoCaptureCount == 1)
        #expect(metrics.isPro() == false)                  // default until bound
    }
}
