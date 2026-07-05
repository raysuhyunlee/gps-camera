import AVFoundation
import ImageIO
import Photos
import UIKit
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

    /// Move a recorded file (e.g. a video temp) into the store under `name`.
    func moveIn(from tempURL: URL, name: String, ext: String) throws -> URL {
        let url = directory.appendingPathComponent("\(name).\(ext)")
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: tempURL, to: url)
        return url
    }
}

/// Add-only Camera Roll copy shared by photo + video capture. Revocation/denial
/// skips silently; the capture already succeeded app-private (foundation
/// permission-coupled policy).
nonisolated enum CameraRoll {
    static func copy(_ url: URL, as type: PHAssetResourceType) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else { return }
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: type, fileURL: url, options: nil)
            }
        }
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
    var saveOriginal = true   // camera.photo.saveOriginal

    private let filename: FilenameProviding
    private let store = CaptureStore()
    private let ext = "jpg"   // TODO: camera.photo.format
    private var pendingSnapshot: LocationSnapshot?
    private var pendingOverlay: RenderedOverlay?
    private var completion: ((Result<URL, Error>) -> Void)?

    init(filename: FilenameProviding) {
        self.filename = filename
    }

    /// `snapshot` is captured by the caller at shutter time (nil = no fix / EXIF off).
    /// `overlayLayer` is the overlay rasterized at shutter time (nil = overlay off).
    func capture(with session: CameraSession,
                 snapshot: LocationSnapshot?,
                 overlayLayer: RenderedOverlay? = nil,
                 shutterSound: Bool = true,
                 completion: @escaping (Result<URL, Error>) -> Void) {
        self.pendingSnapshot = snapshot
        self.pendingOverlay = overlayLayer
        self.completion = completion
        session.capture(delegate: self, shutterSound: shutterSound)
    }

    // Runs on the capture session queue.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error { return finish(.failure(error)) }
        guard var data = photo.fileDataRepresentation() else {
            return finish(.failure(CaptureError.noData))
        }

        // 2. Overlay burn; the pre-burn copy backs camera.photo.saveOriginal.
        var original: Data?
        if let layer = pendingOverlay {
            if saveOriginal { original = data }
            data = burn(layer, into: data)
        }

        // 3. EXIF location (the original keeps it too).
        if exifLocation, let snapshot = pendingSnapshot {
            let gps = GPSMetadata.dictionary(from: snapshot)
            data = merge(gps: gps, into: data)
            original = original.map { merge(gps: gps, into: $0) }
        }

        // 4. Name + 5. persist (app-private, atomic). The `_original` marker is
        // fixed, distinct from the user's filename.suffix (camera.md step 5);
        // the copy is best-effort and never fails the capture.
        let name = filename.makeName(for: Date()) { store.existingBaseNames().contains($0) }
        let url: URL
        do {
            url = try store.write(data, name: name, ext: ext)
        } catch {
            return finish(.failure(error))
        }
        if let original {
            try? store.write(original, name: name + "_original", ext: ext)
        }

        // 6. Copy to Camera Roll (add-only) when enabled.
        if saveToPhotos { CameraRoll.copy(url, as: .photo) }

        // 7. TODO: usage metrics (photo count) -> monetization interstitial.

        finish(.success(url))
    }

    private func finish(_ result: Result<URL, Error>) {
        let completion = completion
        self.completion = nil
        DispatchQueue.main.async { completion?(result) }
    }

    /// Draw the rendered overlay layer at its world-space anchor on the (already
    /// upright) photo, scaled by (photo width / designWidth) so it matches the
    /// live preview, then carry the capture's metadata onto the re-encoded pixels.
    private func burn(_ overlay: RenderedOverlay, into data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let scale = image.size.width / OverlayLayerMetrics.designWidth
        let layer = CGSize(width: overlay.image.size.width * scale,
                           height: overlay.image.size.height * scale)
        let margin = OverlayLayerMetrics.margin * scale
        let anchor = overlay.anchor.unit
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let burned = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
            overlay.image.draw(in: CGRect(
                x: margin + anchor.x * (image.size.width - layer.width - 2 * margin),
                y: margin + anchor.y * (image.size.height - layer.height - 2 * margin),
                width: layer.width, height: layer.height))
        }
        guard let jpeg = burned.jpegData(compressionQuality: 0.95) else { return data }
        // The draw baked the pixels upright; drop the stale orientation + dims.
        var props = properties(of: data)
        props[kCGImagePropertyOrientation as String] = nil
        props[kCGImagePropertyPixelWidth as String] = nil
        props[kCGImagePropertyPixelHeight as String] = nil
        if var tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff[kCGImagePropertyTIFFOrientation as String] = nil
            props[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        return reencode(jpeg, applying: props)
    }

    private func merge(gps: [String: Any], into data: Data) -> Data {
        var props = properties(of: data)
        props[kCGImagePropertyGPSDictionary as String] = gps
        return reencode(data, applying: props)
    }

    private func properties(of data: Data) -> [String: Any] {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return [:] }
        return (CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any]) ?? [:]
    }

    /// Re-encode `data` with `props` applied (pixels pass through untouched).
    private func reencode(_ data: Data, applying props: [String: Any]) -> Data {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(src) else { return data }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, uti, 1, nil) else { return data }
        CGImageDestinationAddImageFromSource(dest, src, 0, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return data }
        return out as Data
    }

    enum CaptureError: Error { case noData }
}
