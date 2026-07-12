//
//  Event.swift
//  Event - the analytics event catalog (event.md "Event Catalog").
//  Other domains fire these; only this domain defines them.
//

import Foundation

enum Event {
    case captureCompleted(kind: CaptureKind)
    case captureFailed(kind: CaptureKind, reason: String)
    case galleryOpened
    case shared
    case paywallShown(source: PaywallSource)
    case purchaseCompleted(product: String)
    case purchaseFailed(product: String, reason: String)
    case settingsChanged(key: String, value: String)
    case adShown
    case reviewRequested
    case onboardingStarted
    case onboardingCompleted
    case onboardingPermission(type: PermissionKind, granted: Bool)

    enum CaptureKind: String { case photo, video }

    enum PermissionKind: String { case location, camera, mic }

    enum PaywallSource: String {
        case mainBanner = "main_banner"
        case settingsBanner = "settings_banner"
        case lockedSetting = "locked_setting"
        case nudge
    }

    var name: String {
        switch self {
        case .captureCompleted: "capture_completed"
        case .captureFailed: "capture_failed"
        case .galleryOpened: "gallery_opened"
        case .shared: "shared"
        case .paywallShown: "paywall_shown"
        case .purchaseCompleted: "purchase_completed"
        case .purchaseFailed: "purchase_failed"
        case .settingsChanged: "settings_changed"
        case .adShown: "ad_shown"
        case .reviewRequested: "review_requested"
        case .onboardingStarted: "onboarding_started"
        case .onboardingCompleted: "onboarding_completed"
        case .onboardingPermission: "onboarding_permission"
        }
    }

    var params: [String: String] {
        switch self {
        case .captureCompleted(let kind):
            ["kind": kind.rawValue]
        case .captureFailed(let kind, let reason):
            ["kind": kind.rawValue, "reason": reason]
        case .galleryOpened, .shared, .adShown, .reviewRequested,
             .onboardingStarted, .onboardingCompleted:
            [:]
        case .onboardingPermission(let type, let granted):
            ["type": type.rawValue, "granted": String(granted)]
        case .paywallShown(let source):
            ["source": source.rawValue]
        case .purchaseCompleted(let product):
            ["product": product]
        case .purchaseFailed(let product, let reason):
            ["product": product, "reason": reason]
        case .settingsChanged(let key, let value):
            ["key": key, "value": value]
        }
    }

    /// Compact, param-safe failure reason (Firebase caps values at 100 chars).
    static func reason(_ error: Error) -> String {
        let e = error as NSError
        return "\(e.domain):\(e.code)"
    }
}
