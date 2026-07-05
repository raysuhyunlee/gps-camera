import SwiftUI

/// Seam consumed by camera (overview.md "Domain wiring"): the overlay layer,
/// reused live on Main and burned into captures (overlay.md "Rendering").
@MainActor protocol OverlayRendering {
    /// Live overlay layer hosted on the Main screen (anchored + draggable);
    /// empty view when disabled. `orientation` is the camera's capture
    /// orientation, frozen while recording / on orientation lock.
    func liveLayer(snapshot: LocationSnapshot?,
                   orientation: UIDeviceOrientation) -> AnyView
    /// Layer rasterized for burning; nil when disabled or empty.
    func renderedLayer(snapshot: LocationSnapshot?) -> RenderedOverlay?
}

/// A rasterized overlay layer plus where to place it on the upright capture.
nonisolated struct RenderedOverlay {
    /// Laid out against `OverlayLayerMetrics.designWidth` points.
    let image: UIImage
    /// World-space 9-grid anchor; the capture is already upright, so
    /// compositors place at `anchor.unit` with no orientation transform.
    let anchor: OverlayAnchor
}

/// Placement contract for compositors of the rendered layer.
nonisolated enum OverlayLayerMetrics {
    /// Width (pt) the layer is laid out against. Compositors scale the layer by
    /// (capture display width / designWidth) so burns match the live preview.
    static let designWidth: CGFloat = 390
    /// Bottom-leading inset (pt, design space).
    static let margin: CGFloat = 16
}
