import SwiftUI

/// Seam consumed by camera (overview.md "Domain wiring"): the recent-capture
/// thumbnail control hosted on Main, which opens the gallery.
protocol GalleryProviding {
    func thumbnailButton() -> AnyView
}

/// Default gallery over the app-private capture store.
final class Gallery: GalleryProviding {
    private let model: GalleryModel

    init(store: CaptureStoreBrowsing) {
        model = GalleryModel(store: store)
    }

    func thumbnailButton() -> AnyView {
        AnyView(GalleryThumbnailButton(model: model))
    }
}
