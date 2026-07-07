//
//  InterstitialAds.swift
//  Monetization - AdMob interstitial executor + the every-N-photos trigger
//  (monetization.md "Ads").
//

import AppTrackingTransparency
import Combine
import GoogleMobileAds
import UIKit

/// AdMob unit config. Debug uses Google's sample interstitial unit.
private nonisolated enum AdMobConfig {
    #if DEBUG
    static let interstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let interstitialUnitID = "ca-app-pub-4083381512720657/1101370813"
    #endif
    /// One interstitial per this many saved photos; counter resets per session.
    static let photosPerAd = 10
}

/// Free users only: requests ATT, initializes the SDK, keeps one interstitial
/// preloaded, and shows it on every 10th saved photo. The trigger runs after
/// the capture has saved (root binds it to `UsageMetrics.onPhotoCapture`), so
/// an ad never blocks an in-progress capture. ObservableObject only for the
/// debug surface (live loaded/error state).
final class InterstitialAds: NSObject, ObservableObject {
    private let entitlement: EntitlementProviding
    private let events: EventTracking
    @Published private var interstitial: InterstitialAd?
    private var loading = false
    private var started = false
    /// Saved photos this session; the ad fires on every multiple of photosPerAd.
    @Published private(set) var sessionPhotoCount = 0
    /// Last load or present failure, for the debug surface (nil = none yet).
    @Published private(set) var lastError: String?
    private var gatingObserver: NSObjectProtocol?

    var isLoaded: Bool { interstitial != nil }

    init(entitlement: EntitlementProviding, events: EventTracking = NoopTracker()) {
        self.entitlement = entitlement
        self.events = events
        super.init()
        // Pro at launch skips ads entirely; if the entitlement later flips to
        // free (expiry, refresh), start mid-session.
        gatingObserver = NotificationCenter.default.addObserver(
            forName: .settingsGatingChanged, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in await self?.start() }
        }
    }

    deinit {
        if let gatingObserver {
            NotificationCenter.default.removeObserver(gatingObserver)
        }
    }

    /// ATT prompt (first launch only) then SDK init + first preload. Called at
    /// launch; no-op for pro (no ads, no prompt). IDFA must resolve before SDK
    /// init for accurate attribution.
    func start() async {
        guard !started, entitlement.entitlement == .free else { return }
        started = true
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            try? await Task.sleep(for: .seconds(1))   // let the launch UI settle
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        await MobileAds.shared.start()
        preload()
    }

    /// The ad trigger: every 10th saved photo, free users only. Runs after the
    /// photo has saved, never during a capture.
    func photoSaved() {
        guard entitlement.entitlement == .free else { return }
        if !started { Task { await start() } }   // entitlement expired mid-session
        sessionPhotoCount += 1
        guard sessionPhotoCount % AdMobConfig.photosPerAd == 0 else { return }
        show()
    }

    /// No-op when nothing is preloaded (offline, no fill) - never blocks or waits.
    func show() {
        guard entitlement.entitlement == .free,
              let ad = interstitial, let top = Self.topViewController()
        else { return }
        interstitial = nil
        ad.present(from: top)   // ad_shown tracked in adWillPresent (real shows only)
    }

    /// Internal for the debug surface's manual reload; production code relies
    /// on start() and the dismiss/fail delegate callbacks.
    func preload() {
        guard !loading, interstitial == nil else { return }
        loading = true
        Task {
            defer { loading = false }
            do {
                let ad = try await InterstitialAd.load(
                    with: AdMobConfig.interstitialUnitID, request: Request())
                ad.fullScreenContentDelegate = self
                interstitial = ad
                lastError = nil
            } catch {
                lastError = error.localizedDescription
                events.record(error, keys: ["ad_unit": AdMobConfig.interstitialUnitID])
            }
        }
    }

    /// Top of the presentation stack: presenting from a view controller that
    /// is already presenting (settings sheet, debug sheet) fails silently.
    private static func topViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension InterstitialAds: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        events.track(.adShown)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        preload()   // the next one is ready before the next 10th photo
    }

    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        lastError = error.localizedDescription
        events.record(error, keys: ["ad_unit": AdMobConfig.interstitialUnitID])
        preload()
    }
}
