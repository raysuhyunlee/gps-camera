import Combine
import SwiftUI

/// `OverlayRendering` backed by `OverlayLayer` + SwiftUI `ImageRenderer`.
/// MainActor: ImageRenderer requires it; camera rasterizes at shutter time, so
/// the burned layer shows shutter-time data (consistent with the EXIF snapshot).
/// ObservableObject: the live view edits `settings.anchor` by drag.
@MainActor final class OverlayRenderer: ObservableObject, OverlayRendering {
    // TODO: read from SettingsStore once the settings framework lands.
    @Published var settings = OverlaySettings()

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
