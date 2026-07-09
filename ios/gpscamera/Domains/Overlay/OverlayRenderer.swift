import Combine
import SwiftUI

/// `OverlayRendering` backed by `OverlayLayer` + SwiftUI `ImageRenderer`.
/// MainActor: ImageRenderer requires it; camera rasterizes at shutter time, so
/// the burned layer shows shutter-time data (consistent with the EXIF snapshot).
/// ObservableObject: the live view re-renders on settings edits + anchor drags.
@MainActor final class OverlayRenderer: ObservableObject, OverlayRendering {
    @Published private(set) var settings: OverlaySettings
    /// Latest map snapshot (map item); republished for the live view + reused by
    /// the burn. nil while the map is off or the first snapshot is in flight.
    @Published private(set) var mapImage: UIImage?
    private let mapSnapshotter = OverlayMapSnapshotter()
    /// Latest coordinate seen, so a scale change can re-snapshot without waiting
    /// for the next location update.
    private var lastCoordinate: Coordinate?
    private let store: SettingsStore
    private let entitlement: EntitlementProviding
    /// Last entitlement `reload()` saw; detects the free -> pro transition.
    private var lastEntitlement: Entitlement
    private var storeChanges: AnyCancellable?
    private var gatingChanges: AnyCancellable?

    /// Construct after the registry has registered defaults into `store`.
    init(store: SettingsStore, entitlement: EntitlementProviding = FixedEntitlement()) {
        self.store = store
        self.entitlement = entitlement
        lastEntitlement = entitlement.entitlement
        settings = OverlaySettings(from: store)
        storeChanges = store.onChange { [weak self] in
            self?.reload()
        }
        // Purchase/expiry while running: re-apply the watermark rule.
        gatingChanges = NotificationCenter.default
            .publisher(for: .settingsGatingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
        reload()
    }

    private func reload() {
        let now = entitlement.entitlement
        let was = lastEntitlement
        lastEntitlement = now
        // Free cannot disable the watermark (overlay.md "Settings"). Flip the
        // stored toggle back on - not just the render - so the Settings row
        // shows the real state after a pro revocation.
        if now == .free, !store.bool(OverlaySettingKey.itemWatermark) {
            store.set(.bool(true), for: OverlaySettingKey.itemWatermark)
        }
        // Becoming pro turns the watermark off once (the reverse of the
        // revocation rule); the toggle stays user-editable afterwards.
        if now == .pro, was == .free, store.bool(OverlaySettingKey.itemWatermark) {
            store.set(.bool(false), for: OverlaySettingKey.itemWatermark)
        }
        settings = OverlaySettings(from: store)
        // Pick up a map-scale (or item) change without a location update.
        refreshMap(for: lastCoordinate)
    }

    /// Drag-to-snap on Main (position editor v1). Synchronous settings update
    /// so the snap animates; the store write persists the anchor.
    func setAnchor(_ anchor: OverlayAnchor) {
        settings.anchor = anchor
        store.set(.string(anchor.rawValue), for: OverlaySettingKey.layout)
    }

    func liveLayer(snapshot: LocationSnapshot?,
                   orientation: UIDeviceOrientation) -> AnyView {
        refreshMap(for: snapshot?.coordinate)
        let layer = OverlayLayer(snapshot: snapshot, settings: settings)
        guard settings.enabled, !layer.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(OverlayLiveView(renderer: self, snapshot: snapshot,
                                       orientation: orientation))
    }

    /// Keep the map snapshot tracking the current coordinate + scale (map item).
    /// Called from `liveLayer` and `reload`; the snapshotter dedups itself.
    private func refreshMap(for coordinate: Coordinate?) {
        if let coordinate { lastCoordinate = coordinate }
        guard settings.enabled, settings.showMap else { return }
        mapSnapshotter.refresh(for: coordinate ?? lastCoordinate,
                               spanMeters: settings.mapScale.spanMeters) { [weak self] image in
            self?.mapImage = image
        }
    }

    func renderedLayer(snapshot: LocationSnapshot?) -> RenderedOverlay? {
        let layer = OverlayLayer(snapshot: snapshot, settings: settings, mapImage: mapImage)
        guard settings.enabled, !layer.isEmpty else { return nil }
        let renderer = ImageRenderer(content: layer)
        // Enough pixels for a 4032px-wide capture (4032 / 390 ≈ 10.3).
        renderer.scale = 12
        guard let image = renderer.uiImage else { return nil }
        return RenderedOverlay(image: image, anchor: settings.anchor)
    }
}
