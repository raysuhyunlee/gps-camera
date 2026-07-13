import Foundation

/// One capture in the gallery, backed by a `CaptureEntry` from the capture
/// store (camera.md "Storage"). Identity is the Photos asset id: the media
/// lives in the library, so there is no stable file URL to key on.
nonisolated struct GalleryItem: Identifiable, Hashable {
    enum Kind { case photo, video }

    let entry: CaptureEntry
    let kind: Kind
    var id: String { entry.id }
    var name: String { entry.filename }

    init(entry: CaptureEntry) {
        self.entry = entry
        kind = Self.videoExtensions.contains(entry.ext.lowercased()) ? .video : .photo
    }

    private static let videoExtensions: Set<String> = ["mov", "mp4"]
}

extension Array where Element == GalleryItem {
    /// The multi-selected items, in list order (newest first).
    func selected(_ ids: Set<String>) -> [GalleryItem] { filter { ids.contains($0.id) } }

    /// Selection to fall back to after deleting `item` from this (pre-delete)
    /// list: the item that takes its index, else the new last, nil when empty.
    func nextSelection(afterDeleting item: GalleryItem) -> GalleryItem? {
        let remaining = filter { $0 != item }
        guard !remaining.isEmpty else { return nil }
        let index = firstIndex(of: item) ?? 0
        return remaining[Swift.min(index, remaining.count - 1)]
    }
}
