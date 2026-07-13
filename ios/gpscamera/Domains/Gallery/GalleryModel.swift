import Combine
import UIKit

/// Items + thumbnails over the capture store (gallery.md). Views call
/// `refresh()` on appearance and on `.captureStoreDidChange`; deletes go
/// through here so the caches stay consistent.
///
/// The media lives in the Photos library, so the store - not the model - reads
/// it: the model caches what the store hands back (thumbnails for the grid,
/// exported files for viewing, playback and share).
@MainActor
final class GalleryModel: ObservableObject {
    @Published private(set) var items: [GalleryItem] = []
    /// Fires gallery_opened / shared from the views (event.md).
    let events: EventTracking
    private let store: CaptureStoreBrowsing
    private let thumbnails = NSCache<NSString, UIImage>()
    private var files: [String: URL] = [:]

    static let thumbnailMaxPixel: CGFloat = 480

    init(store: CaptureStoreBrowsing, events: EventTracking) {
        self.store = store
        self.events = events
    }

    var latest: GalleryItem? { items.first }

    func refresh() async {
        items = await store.entries().map(GalleryItem.init)
    }

    func delete(_ item: GalleryItem) async { await delete([item]) }

    /// Photos runs the deletion confirmation itself; a cancel leaves the items
    /// in place (gallery.md "Details").
    func delete(_ items: [GalleryItem]) async {
        guard await store.delete(items.map(\.entry)) else { return }
        for item in items {
            thumbnails.removeObject(forKey: item.id as NSString)
            files[item.id] = nil
        }
        await refresh()
    }

    /// Grid/thumbnail image, cached.
    func thumbnail(for item: GalleryItem) async -> UIImage? {
        if let cached = thumbnails.object(forKey: item.id as NSString) { return cached }
        let image = await store.thumbnail(for: item.entry, maxPixel: Self.thumbnailMaxPixel)
        if let image { thumbnails.setObject(image, forKey: item.id as NSString) }
        return image
    }

    /// Full-resolution file for the viewer, playback and share. Exporting it out
    /// of the library is slow for video, so the result is kept for the session.
    func fileURL(for item: GalleryItem) async -> URL? {
        if let cached = files[item.id] { return cached }
        let url = await store.fileURL(for: item.entry)
        files[item.id] = url
        return url
    }
}
