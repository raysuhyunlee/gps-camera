import Foundation

extension Notification.Name {
    /// Posted by `CaptureStore` after a file lands or is deleted. May arrive on
    /// the capture-session queue; hop to main before touching UI state.
    static let captureStoreDidChange = Notification.Name("captureStoreDidChange")
}

/// Seam consumed by gallery (overview.md "Domain wiring"): browse + delete the
/// app-private capture store (camera.md "Storage"). Writing stays camera-internal.
nonisolated protocol CaptureStoreBrowsing: Sendable {
    /// Every media file in the store, newest first.
    func mediaURLs() -> [URL]
    func delete(_ url: URL) throws
}

nonisolated extension CaptureStore: CaptureStoreBrowsing {
    func mediaURLs() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return urls.sorted { creationDate($0) > creationDate($1) }
    }

    func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
        NotificationCenter.default.post(name: .captureStoreDidChange, object: nil)
    }

    private func creationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }
}
