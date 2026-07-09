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
    /// Map item box side (pt, design space); sits left of the info card.
    static let mapSide: CGFloat = 96
    /// Gap between the map box and the info card - they read as separate objects.
    static let mapGap: CGFloat = 8
    /// Point size the map snapshot is rendered at (4x mapSide) so it stays crisp
    /// when the layer is scaled up at burn time.
    static let mapRenderSide: Double = 384
}
