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
    private let gallery: Gallery
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
        // Before `onSet`: the language write below re-geocodes through it.
        let location = LocationProvider()
        location.preferredLocale = L10n.shared.locale
        store.onSet = { key, value in
            events.track(.settingsChanged(key: key, value: "\(value.primitive)"))
            if key == L10n.settingKey {
                L10n.shared.setLanguage(value.stringValue)
                // Addresses come back from the geocoder in the app language.
                location.preferredLocale = L10n.shared.locale
                location.refreshAddress()
            }
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
        // Keys with no Settings row to carry their default; register here.
        Onboarding.registerDefaults(store)
        Camera.registerDefaults(store)
        // Captures land in the Photos library; the store indexes the app's own
        // assets, and the gallery browses that index (camera.md "Storage").
        let library = PhotoLibraryStore()
        var captures: CaptureStoreBrowsing = library
        #if DEBUG
        // Screenshot demo mode: skip onboarding + browse bundled demo captures so
        // the simulator renders finished screens (screenshots.md). Entitlement is
        // forced inside ProStore; the scene/location are read where used.
        if ScreenshotDemo.current.isActive {
            store.set(.bool(true), for: Onboarding.completedKey)
            if let locale = ScreenshotDemo.current.locale {
                store.set(.string(locale), for: L10n.settingKey)   // fires L10n via onSet
            }
            captures = DemoCaptureStore()
        }
        #endif
        let overlay = OverlayRenderer(store: store, entitlement: pro)
        self.events = events
        self.store = store
        self.registry = registry
        self.overlay = overlay
        self.pro = pro
        self.ads = ads
        self.metrics = metrics
        // Gallery browses the same captures the capture services write.
        self.gallery = Gallery(store: captures, events: events)
        _location = StateObject(wrappedValue: location)
        _camera = StateObject(wrappedValue: CameraController(
            location: location, overlay: overlay,
            filename: DefaultFilenameProvider(store: store), captures: library,
            store: store, events: events, metrics: metrics))
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ScreenshotDemo.current.isActive {
                ScreenshotPoseHost(
                    screen: ScreenshotDemo.current.screen,
                    main: cameraView,
                    settings: {
                        AnyView(SettingsScreen(
                            registry: registry, store: store,
                            entitled: { pro.entitlement == .pro },
                            onProLock: { _ in },
                            highlightKey: OverlaySettingKey.enabled))
                    },
                    gallery: { gallery.screenshotScreen() })
            } else {
                rootView
            }
            #else
            rootView
            #endif
        }
    }

    private var rootView: some View {
        RootView(store: store, location: location, events: events,
                 onOnboarded: { Task { await ads.start() } }) {
            cameraView
        }
    }

    private var cameraView: some View {
        CameraView(controller: camera, location: location, overlay: overlay,
                   gallery: gallery, settings: store, registry: registry,
                   entitlement: pro, paywall: pro, banner: pro, ads: ads,
                   metrics: metrics)
    }
}
