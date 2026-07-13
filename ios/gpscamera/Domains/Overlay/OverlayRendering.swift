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
    /// Width (pt) of the reference picture. Live and media renderers scale every
    /// layout value by (actual picture width / designWidth).
    static let designWidth: CGFloat = 390
    /// Edge inset (pt, reference space).
    static let margin: CGFloat = 16
    /// Map item box side (pt, design space); sits left of the info card.
    static let mapSide: CGFloat = 96
    /// Gap between the map box and the info card - they read as separate objects.
    static let mapGap: CGFloat = 8
    /// Point size the map snapshot is rendered at (4x mapSide) so it stays crisp
    /// when the layer is scaled up at burn time.
    static let mapRenderSide: Double = 384

    /// Maximum layer width in reference space.
    static let maximumWidth = designWidth - 2 * margin

    /// Reference points to media pixels.
    static func mediaScale(for mediaSize: CGSize) -> CGFloat {
        mediaSize.width / designWidth
    }

    static func mediaMargin(for mediaSize: CGSize) -> CGFloat {
        margin * mediaScale(for: mediaSize)
    }

    /// Scales a reference-space layer into media pixels and enforces the actual
    /// media width after its scaled left and right margins are removed.
    static func mediaLayerSize(_ referenceSize: CGSize,
                               in mediaSize: CGSize) -> CGSize {
        guard referenceSize.width > 0, referenceSize.height > 0 else { return .zero }
        let scale = mediaScale(for: mediaSize)
        let maximumMediaWidth = max(0, mediaSize.width - 2 * mediaMargin(for: mediaSize))
        let fittedScale = min(scale, maximumMediaWidth / referenceSize.width)
        return CGSize(width: referenceSize.width * fittedScale,
                      height: referenceSize.height * fittedScale)
    }
}
