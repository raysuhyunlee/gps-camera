import Photos
import UIKit

extension Notification.Name {
    /// Posted by the capture store after an asset lands or is deleted. May
    /// arrive off the main queue; hop to main before touching UI state.
    nonisolated static let captureStoreDidChange = Notification.Name("captureStoreDidChange")
}

/// Seam consumed by gallery (overview.md "Domain wiring"): browse + delete the
/// app's own captures. Writing stays camera-internal. The store owns media
/// access (the media lives in Photos, not in a directory the gallery can walk);
/// the gallery owns presentation and caching.
nonisolated protocol CaptureStoreBrowsing: Sendable {
    /// The app's captures, newest first, pruned of anything deleted in Photos.
    func entries() async -> [CaptureEntry]
    func thumbnail(for entry: CaptureEntry, maxPixel: CGFloat) async -> UIImage?
    /// Full-resolution media as a file, for full-screen view, playback + share.
    func fileURL(for entry: CaptureEntry) async -> URL?
    /// Photos runs its own confirmation; false when the user cancels it.
    func delete(_ entries: [CaptureEntry]) async -> Bool
}

nonisolated extension PhotoLibraryStore: CaptureStoreBrowsing {
    func entries() async -> [CaptureEntry] {
        let known = index.all()
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: known.map(\.id), options: nil)
        var live = Set<String>()
        assets.enumerateObjects { asset, _, _ in live.insert(asset.localIdentifier) }
        index.keep(ids: live)
        return known.filter { live.contains($0.id) }
    }

    func thumbnail(for entry: CaptureEntry, maxPixel: CGFloat) async -> UIImage? {
        guard let asset = asset(for: entry) else { return nil }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat   // one callback, no degraded pass
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true       // iCloud-optimized originals
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: maxPixel, height: maxPixel),
                contentMode: .aspectFill,
                options: options) { image, _ in continuation.resume(returning: image) }
        }
    }

    /// Exports the asset's original resource to a temp file under its capture
    /// name, so share sheets and the file the user receives carry that name.
    /// Cached: paging back and forth must not re-export.
    func fileURL(for entry: CaptureEntry) async -> URL? {
        guard let asset = asset(for: entry),
              let resource = PHAssetResource.assetResources(for: asset).first
        else { return nil }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("captures/\(entry.id.replacingOccurrences(of: "/", with: "-"))",
                                    isDirectory: true)
        let url = directory.appendingPathComponent(entry.filename)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().writeData(for: resource, toFile: url,
                                                       options: options) { error in
                continuation.resume(returning: error == nil ? url : nil)
            }
        }
    }

    func delete(_ entries: [CaptureEntry]) async -> Bool {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: entries.map(\.id), options: nil)
        guard assets.count > 0 else {
            index.remove(ids: Set(entries.map(\.id)))   // already gone in Photos
            return true
        }
        let deleted: Bool = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            } completionHandler: { ok, _ in continuation.resume(returning: ok) }
        }
        guard deleted else { return false }   // user cancelled the Photos confirmation
        index.remove(ids: Set(entries.map(\.id)))
        NotificationCenter.default.post(name: .captureStoreDidChange, object: nil)
        return true
    }

    private func asset(for entry: CaptureEntry) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [entry.id], options: nil).firstObject
    }
}
