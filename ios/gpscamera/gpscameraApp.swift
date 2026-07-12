//
//  gpscameraApp.swift
//  gpscamera
//
//  Composition root: constructs domains and wires them into screens.
//

import SwiftUI

@main
struct gpscameraApp: App {
    @StateObject private var location: LocationProvider
    @StateObject private var camera: CameraController
    private let overlay: OverlayRenderer
    private let gallery: GalleryProviding
    private let store: SettingsStore
    private let registry: SettingsRegistry
    /// Live entitlement + paywall + banners (monetization).
    private let pro: ProStore
    /// Interstitials for free users, triggered every 10th saved photo.
    private let ads: InterstitialAds
    /// Kept for the debug surface's usage-metrics section.
    private let metrics: UsageMetrics
    /// Injected into the onboarding gate (fires onboarding_* events).
    private let events: EventTracking

    init() {
        BundledFonts.registerAll()   // before any UI renders
        // Analytics first: consumers receive the tracker at construction
        // (event.md). Session start lands before any event fires.
        let metrics = UsageMetrics()
        metrics.recordSessionStart()
        let events = FirebaseTracker(metrics: metrics)
        // Registry before consumers: it registers every setting's default.
        // Section placement is owned here (overview.md "Settings").
        let store = SettingsStore()
        store.onSet = { key, value in
            events.track(.settingsChanged(key: key, value: "\(value.primitive)"))
            if key == L10n.settingKey { L10n.shared.setLanguage(value.stringValue) }
        }
        let pro = ProStore(events: events)
        metrics.isPro = { pro.entitlement == .pro }
        // Nudges + the ad trigger ride the usage-metrics capture hooks
        // (monetization.md "Nudge orchestrator", "Ads"); ATT prompt + SDK
        // init after onboarding's camera/location prompts resolve (started via
        // RootView's onOnboarded below), free users only.
        let ads = InterstitialAds(entitlement: pro, metrics: metrics,
                                  events: events)
        let nudges = NudgeOrchestrator(metrics: metrics, store: pro, ads: ads,
                                       events: events)
        metrics.onCapture = { nudges.captureCompleted() }
        let registry = SettingsRegistry(
            providers: [MonetizationSettingsProvider(store: pro),
                        FoundationSettingsProvider(),
                        CameraSettingsProvider(), OverlaySettingsProvider(),
                        FilenameSettingsProvider()],
            order: ["monetization": 0, "foundation.general": 10,
                    "camera.capture": 20, "overlay": 30, "filename": 40,
                    "monetization.restore": 90, "foundation.feedback": 91,
                    "foundation.about": 92],
            store: store)
        Onboarding.registerDefaults(store)   // no Settings section; register here
        #if DEBUG
        // Screenshot demo mode: skip onboarding + seed the gallery so the
        // simulator renders finished screens (screenshots.md). Entitlement is
        // forced inside ProStore; the scene/location are read where used.
        if ScreenshotDemo.current.isActive {
            store.set(.bool(true), for: Onboarding.completedKey)
            if let locale = ScreenshotDemo.current.locale {
                store.set(.string(locale), for: L10n.settingKey)   // fires L10n via onSet
            }
            ScreenshotSeed.seedCaptures()
        }
        #endif
        let location = LocationProvider()
        let overlay = OverlayRenderer(store: store, entitlement: pro)
        self.events = events
        self.store = store
        self.registry = registry
        self.overlay = overlay
        self.pro = pro
        self.ads = ads
        self.metrics = metrics
        // Gallery browses the same app-private store the capture services write.
        self.gallery = Gallery(store: CaptureStore(), events: events)
        _location = StateObject(wrappedValue: location)
        _camera = StateObject(wrappedValue: CameraController(
            location: location, overlay: overlay,
            filename: DefaultFilenameProvider(store: store), store: store,
            events: events, metrics: metrics))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, location: location, events: events,
                     onOnboarded: { Task { await ads.start() } }) {
                CameraView(controller: camera, location: location, overlay: overlay,
                           gallery: gallery, settings: store, registry: registry,
                           entitlement: pro, paywall: pro, banner: pro, ads: ads,
                           metrics: metrics)
            }
        }
    }
}
