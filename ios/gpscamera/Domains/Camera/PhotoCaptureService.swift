import AVFoundation
import ImageIO
import Photos
import UniformTypeIdentifiers

/// App-private capture store — the gallery's future source of truth (camera.md
/// "Storage"). Lives under Application Support; never touches the system library.
nonisolated struct CaptureStore {
    let directory: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        directory = base.appendingPathComponent("Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
    }

    /// Base names already in the store (extension stripped) — for auto-number.
    func existingBaseNames() -> Set<String> {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        return Set(urls.map { $0.deletingPathExtension().lastPathComponent })
    }

    /// Atomic write (camera.md "Durability").
    func write(_ data: Data, name: String, ext: String) throws -> URL {
        let url = directory.appendingPathComponent("\(name).\(ext)")
        try data.write(to: url, options: .atomic)
        return url
    }
}

/// The photo capture pipeline (camera.md "Capture pipeline").
/// Steps not yet backed by a domain are stubbed with a marker.
/// `nonisolated`: the photo delegate fires on the capture session queue.
nonisolated final class PhotoCaptureService: NSObject, AVCapturePhotoCaptureDelegate {
    // Capture settings — hardcoded to spec defaults until the settings
    // framework lands. TODO: read from SettingsStore.
    var exifLocation = true   // camera.exif.location
    var saveToPhotos = true   // camera.saveToPhotos

    private let filename: FilenameProviding
    private let store = CaptureStore()
    private let ext = "jpg"   // TODO: camera.photo.format
    private var pendingSnapshot: LocationSnapshot?
    private var completion: ((Result<URL, Error>) -> Void)?

    init(filename: FilenameProviding) {
        self.filename = filename
    }

    /// `snapshot` is captured by the caller at shutter time (nil = no fix / EXIF off).
    func capture(with session: CameraSession,
                 snapshot: LocationSnapshot?,
                 completion: @escaping (Result<URL, Error>) -> Void) {
        self.pendingSnapshot = snapshot
        self.completion = completion
        session.capture(delegate: self)
    }

    // Runs on the capture session queue.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error { return finish(.failure(error)) }
        guard var data = photo.fileDataRepresentation() else {
            return finish(.failure(CaptureError.noData))
        }

        // 2. Overlay burn — skipped: no overlay domain yet (nil seam).

        // 3. EXIF location.
        if exifLocation, let snapshot = pendingSnapshot {
            data = merge(gps: GPSMetadata.dictionary(from: snapshot), into: data)
        }

        // 4. Name + 5. persist (app-private, atomic).
        let name = filename.makeName(for: Date()) { store.existingBaseNames().contains($0) }
        let url: URL
        do {
            url = try store.write(data, name: name, ext: ext)
        } catch {
            return finish(.failure(error))
        }
        // saveOriginal is a no-op until overlay exists (original == overlaid).

        // 6. Copy to Camera Roll (add-only) when enabled.
        if saveToPhotos { copyToCameraRoll(url) }

        // 7. TODO: usage metrics (photo count) -> monetization interstitial.

        finish(.success(url))
    }

    private func finish(_ result: Result<URL, Error>) {
        let completion = completion
        self.completion = nil
        DispatchQueue.main.async { completion?(result) }
    }

    private func merge(gps: [String: Any], into data: Data) -> Data {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(src) else { return data }
        var props = (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]) ?? [:]
        props[kCGImagePropertyGPSDictionary as String] = gps
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, uti, 1, nil) else { return data }
        CGImageDestinationAddImageFromSource(dest, src, 0, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return data }
        return out as Data
    }

    /// Add-only Camera Roll copy. Revocation/denial skips silently; the capture
    /// already succeeded app-private (foundation permission-coupled policy).
    private func copyToCameraRoll(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: url, options: nil)
            }
        }
    }

    enum CaptureError: Error { case noData }
}
