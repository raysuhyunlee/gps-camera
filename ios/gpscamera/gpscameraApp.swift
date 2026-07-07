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
        store.onSet = { events.track(.settingsChanged(key: $0, value: "\($1.primitive)")) }
        let pro = ProStore(events: events)
        metrics.isPro = { pro.entitlement == .pro }
        // Ad trigger rides the usage-metrics hook (monetization.md "Ads");
        // ATT prompt + SDK init at launch, free users only.
        let ads = InterstitialAds(entitlement: pro, events: events)
        metrics.onPhotoCapture = { ads.photoSaved() }
        Task { await ads.start() }
        let registry = SettingsRegistry(
            providers: [MonetizationSettingsProvider(store: pro),
                        CameraSettingsProvider(), OverlaySettingsProvider(),
                        FilenameSettingsProvider()],
            order: ["monetization": 0, "camera.capture": 20, "overlay": 30,
                    "filename": 40, "monetization.restore": 90],
            store: store)
        let location = LocationProvider()
        let overlay = OverlayRenderer(store: store, entitlement: pro)
        self.store = store
        self.registry = registry
        self.overlay = overlay
        self.pro = pro
        self.ads = ads
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
            CameraView(controller: camera, location: location, overlay: overlay,
                       gallery: gallery, settings: store, registry: registry,
                       entitlement: pro, paywall: pro, banner: pro, ads: ads)
        }
    }
}
