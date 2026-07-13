import SwiftUI

/// Live overlay host: places the layer at its 9-grid anchor in world space,
/// keeps it there across device rotation (relocate + counter-rotate, animated),
/// and lets the user drag it to another anchor - the position editor v1
/// (overlay.md "Position & scale editor"; free positioning/scaling deferred).
struct OverlayLiveView: View {
    @ObservedObject var renderer: OverlayRenderer
    let snapshot: LocationSnapshot?
    let orientation: UIDeviceOrientation

    @State private var layerSize = CGSize.zero
    @State private var dragOffset = CGSize.zero

    /// Stationary space for the drag - reading the gesture in the moving
    /// layer's local space feeds its own translation back and shakes.
    private static let space = "overlay-live"

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / OverlayLayerMetrics.designWidth
            let footprint = footprint(scale: scale)
            let center = anchorCenter(in: geo.size, footprint: footprint,
                                      margin: OverlayLayerMetrics.margin * scale)
            OverlayLayer(snapshot: snapshot, settings: renderer.settings,
                         mapImage: renderer.mapImage)
                .onGeometryChange(for: CGSize.self, of: \.size) { layerSize = $0 }
                .scaleEffect(scale)
                .rotationEffect(OverlayAnchor.angle(for: orientation))
                // The rotated layer's screen-space bounding box, so quarter
                // turns anchor by their visual edges, not the layout frame.
                .frame(width: footprint.width, height: footprint.height)
                .gesture(drag(in: geo.size, footprint: footprint,
                              margin: OverlayLayerMetrics.margin * scale))
                .position(x: center.x + dragOffset.width,
                          y: center.y + dragOffset.height)
                .animation(.easeInOut(duration: 0.25), value: orientation)
        }
        .coordinateSpace(name: Self.space)
    }

    /// Bounding box of the counter-rotated layer (quarter turns swap the axes).
    private func footprint(scale: CGFloat) -> CGSize {
        let scaled = CGSize(width: layerSize.width * scale,
                            height: layerSize.height * scale)
        return orientation.isLandscape
            ? CGSize(width: scaled.height, height: scaled.width)
            : scaled
    }

    private func anchorCenter(in size: CGSize, footprint: CGSize,
                              margin: CGFloat) -> CGPoint {
        let u = renderer.settings.anchor.screenUnit(for: orientation)
        return CGPoint(
            x: margin + footprint.width / 2
                + u.x * (size.width - footprint.width - 2 * margin),
            y: margin + footprint.height / 2
                + u.y * (size.height - footprint.height - 2 * margin))
    }

    /// Follow the finger, then snap to the nearest of the 9 anchors - resolved
    /// in world space so the drag works the same at any device orientation.
    private func drag(in size: CGSize, footprint: CGSize,
                      margin: CGFloat) -> some Gesture {
        DragGesture(coordinateSpace: .named(Self.space))
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let center = anchorCenter(in: size, footprint: footprint,
                                          margin: margin)
                let screen = CGPoint(
                    x: min(max((center.x + value.translation.width) / size.width, 0), 1),
                    y: min(max((center.y + value.translation.height) / size.height, 0), 1))
                let world = OverlayAnchor.worldUnit(fromScreen: screen,
                                                    orientation: orientation)
                withAnimation(.easeInOut(duration: 0.25)) {
                    renderer.setAnchor(OverlayAnchor(nearest: world))
                    dragOffset = .zero
                }
            }
    }
}
