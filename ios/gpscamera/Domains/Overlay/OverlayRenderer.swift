import Combine
import SwiftUI

/// `OverlayRendering` backed by `OverlayLayer` + SwiftUI `ImageRenderer`.
/// MainActor: ImageRenderer requires it; camera rasterizes at shutter time, so
/// the burned layer shows shutter-time data (consistent with the EXIF snapshot).
/// ObservableObject: the live view re-renders on settings edits + anchor drags.
@MainActor final class OverlayRenderer: ObservableObject, OverlayRendering {
    @Published private(set) var settings: OverlaySettings
    private let store: SettingsStore
    private let entitlement: EntitlementProviding
    private var storeChanges: AnyCancellable?
    private var gatingChanges: AnyCancellable?

    /// Construct after the registry has registered defaults into `store`.
    init(store: SettingsStore, entitlement: EntitlementProviding = FixedEntitlement()) {
        self.store = store
        self.entitlement = entitlement
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
        // Free cannot disable the watermark (overlay.md "Settings"). Flip the
        // stored toggle back on - not just the render - so the Settings row
        // shows the real state after a pro revocation.
        if entitlement.entitlement == .free,
           !store.bool(OverlaySettingKey.itemWatermark) {
            store.set(.bool(true), for: OverlaySettingKey.itemWatermark)
        }
        settings = OverlaySettings(from: store)
    }

    /// Drag-to-snap on Main (position editor v1). Synchronous settings update
    /// so the snap animates; the store write persists the anchor.
    func setAnchor(_ anchor: OverlayAnchor) {
        settings.anchor = anchor
        store.set(.string(anchor.rawValue), for: OverlaySettingKey.layout)
    }

    func liveLayer(snapshot: LocationSnapshot?,
                   orientation: UIDeviceOrientation) -> AnyView {
        let layer = OverlayLayer(snapshot: snapshot, settings: settings)
        guard settings.enabled, !layer.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(OverlayLiveView(renderer: self, snapshot: snapshot,
                                       orientation: orientation))
    }

    func renderedLayer(snapshot: LocationSnapshot?) -> RenderedOverlay? {
        let layer = OverlayLayer(snapshot: snapshot, settings: settings)
        guard settings.enabled, !layer.isEmpty else { return nil }
        let renderer = ImageRenderer(content: layer)
        // Enough pixels for a 4032px-wide capture (4032 / 390 ≈ 10.3).
        renderer.scale = 12
        guard let image = renderer.uiImage else { return nil }
        return RenderedOverlay(image: image, anchor: settings.anchor)
    }
}
