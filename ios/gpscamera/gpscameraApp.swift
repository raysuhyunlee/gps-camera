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
    private let entitlement: EntitlementProviding = FixedEntitlement()

    init() {
        BundledFonts.registerAll()   // before any UI renders
        // Registry before consumers: it registers every setting's default.
        // Section placement is owned here (overview.md "Settings").
        let store = SettingsStore()
        let registry = SettingsRegistry(
            providers: [CameraSettingsProvider(), OverlaySettingsProvider(),
                        FilenameSettingsProvider()],
            order: ["camera.capture": 20, "overlay": 30, "filename": 40],
            store: store)
        let location = LocationProvider()
        let overlay = OverlayRenderer(store: store)
        self.store = store
        self.registry = registry
        self.overlay = overlay
        // Gallery browses the same app-private store the capture services write.
        self.gallery = Gallery(store: CaptureStore())
        _location = StateObject(wrappedValue: location)
        _camera = StateObject(wrappedValue: CameraController(
            location: location, overlay: overlay,
            filename: DefaultFilenameProvider(store: store), store: store))
    }

    var body: some Scene {
        WindowGroup {
            CameraView(controller: camera, location: location, overlay: overlay,
                       gallery: gallery, settings: store, registry: registry,
                       entitlement: entitlement)
        }
    }
}
