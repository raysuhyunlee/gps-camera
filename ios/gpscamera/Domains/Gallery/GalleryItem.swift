import Foundation

/// One media file in the capture store; kind is derived from the extension.
nonisolated struct GalleryItem: Identifiable, Hashable {
    enum Kind { case photo, video }

    let url: URL
    let kind: Kind
    var id: URL { url }

    init(url: URL) {
        self.url = url
        kind = Self.videoExtensions.contains(url.pathExtension.lowercased())
            ? .video : .photo
    }

    private static let videoExtensions: Set<String> = ["mov", "mp4"]
}

extension Array where Element == GalleryItem {
    /// The multi-selected items, in list order (newest first).
    func selected(_ ids: Set<URL>) -> [GalleryItem] { filter { ids.contains($0.url) } }

    /// Selection to fall back to after deleting `item` from this (pre-delete)
    /// list: the item that takes its index, else the new last, nil when empty.
    func nextSelection(afterDeleting item: GalleryItem) -> GalleryItem? {
        let remaining = filter { $0 != item }
        guard !remaining.isEmpty else { return nil }
        let index = firstIndex(of: item) ?? 0
        return remaining[Swift.min(index, remaining.count - 1)]
    }
}
