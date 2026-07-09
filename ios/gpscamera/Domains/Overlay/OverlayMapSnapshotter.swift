import MapKit
import SwiftUI

/// Renders a static map image centered on the current coordinate for the map
/// overlay item (overlay.md "Items"). `MKMapSnapshotter` is async and
/// UIImage-backed, so the one snapshot feeds both the live layer and the
/// `ImageRenderer` burn - a live MapKit view would not rasterize.
@MainActor final class OverlayMapSnapshotter {
    /// Center + span of the last snapshot; a new one is skipped while both hold.
    private var renderedCenter: CLLocationCoordinate2D?
    private var renderedSpan: Double?
    private var pending: MKMapSnapshotter?

    /// Snapshot `coordinate` at `spanMeters` zoom and deliver the image on the
    /// main actor. No-op when the coordinate has barely moved and the span is
    /// unchanged (still shows the previous image).
    func refresh(for coordinate: Coordinate?, spanMeters: Double,
                 completion: @escaping @MainActor (UIImage) -> Void) {
        guard let coordinate else { return }
        let center = CLLocationCoordinate2D(latitude: coordinate.latitude,
                                            longitude: coordinate.longitude)
        if let last = renderedCenter, renderedSpan == spanMeters,
           distance(last, center) < 15 { return }
        renderedCenter = center
        renderedSpan = spanMeters
        pending?.cancel()

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: spanMeters, longitudinalMeters: spanMeters)
        options.size = CGSize(width: OverlayLayerMetrics.mapRenderSide,
                              height: OverlayLayerMetrics.mapRenderSide)
        let snapshotter = MKMapSnapshotter(options: options)
        pending = snapshotter
        snapshotter.start(with: .main) { snapshot, _ in
            guard let snapshot else { return }
            MainActor.assumeIsolated { completion(snapshot.image) }
        }
    }

    private func distance(_ a: CLLocationCoordinate2D,
                          _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
