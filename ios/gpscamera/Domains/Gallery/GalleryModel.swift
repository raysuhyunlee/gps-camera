import AVFoundation
import Combine
import ImageIO
import UIKit

/// Items + thumbnails over the capture store (gallery.md). Views call
/// `refresh()` on appearance and on `.captureStoreDidChange`; deletes go
/// through here so the cache stays consistent.
final class GalleryModel: ObservableObject {
    @Published private(set) var items: [GalleryItem] = []
    /// Fires gallery_opened / shared from the views (event.md).
    let events: EventTracking
    private let store: CaptureStoreBrowsing
    private let thumbnails = NSCache<NSURL, UIImage>()

    init(store: CaptureStoreBrowsing, events: EventTracking) {
        self.store = store
        self.events = events
        refresh()
    }

    var latest: GalleryItem? { items.first }

    func refresh() {
        items = store.mediaURLs().map(GalleryItem.init)
    }

    func delete(_ item: GalleryItem) { delete([item]) }

    func delete(_ items: [GalleryItem]) {
        for item in items {
            try? store.delete(item.url)
            thumbnails.removeObject(forKey: item.url as NSURL)
        }
        refresh()
    }

    /// Grid/thumbnail image, decoded off the main actor and cached.
    func thumbnail(for item: GalleryItem) async -> UIImage? {
        if let cached = thumbnails.object(forKey: item.url as NSURL) { return cached }
        let image = await Task.detached(priority: .userInitiated) {
            await Thumbnailer.make(for: item)
        }.value
        if let image { thumbnails.setObject(image, forKey: item.url as NSURL) }
        return image
    }
}

/// Decodes small previews; nonisolated so it runs on the detached task's thread.
private nonisolated enum Thumbnailer {
    static let maxPixel: CGFloat = 480

    static func make(for item: GalleryItem) async -> UIImage? {
        switch item.kind {
        case .photo: return photo(at: item.url)
        case .video: return await video(at: item.url)
        }
    }

    private static func photo(at url: URL) -> UIImage? {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: maxPixel] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }

    private static func video(at url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixel, height: maxPixel)
        guard let cg = try? await generator.image(at: .zero).image else { return nil }
        return UIImage(cgImage: cg)
    }
}
