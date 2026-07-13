import AVFoundation
import ImageIO
import Photos
import UIKit
import UniformTypeIdentifiers

/// Settings snapshot for one capture, resolved by the controller at shutter
/// time (permission-coupled values already effective - foundation.md).
nonisolated struct PhotoCaptureOptions {
    var exifLocation = true                        // camera.exif.location (effective)
    var saveOriginal = true                        // camera.photo.saveOriginal (shared)
    var format = CameraSettings.PhotoFormat.jpg    // camera.photo.format
    var shutterSound = true                        // camera.shutterSound
}

/// The photo capture pipeline (camera.md "Capture pipeline").
/// Steps not yet backed by a domain are stubbed with a marker.
/// `nonisolated`: the photo delegate fires on the capture session queue.
nonisolated final class PhotoCaptureService: NSObject, AVCapturePhotoCaptureDelegate {
    private let filename: FilenameProviding
    private let store: PhotoLibraryStore
    private var options = PhotoCaptureOptions()
    private var pendingSnapshot: LocationSnapshot?
    private var pendingOverlay: RenderedOverlay?
    private var completion: ((Result<Void, Error>) -> Void)?

    init(filename: FilenameProviding, store: PhotoLibraryStore) {
        self.filename = filename
        self.store = store
    }

    /// `snapshot` is captured by the caller at shutter time (nil = no fix / EXIF off).
    /// `overlayLayer` is the overlay rasterized at shutter time (nil = overlay off).
    func capture(with session: CameraSession,
                 snapshot: LocationSnapshot?,
                 overlayLayer: RenderedOverlay? = nil,
                 options: PhotoCaptureOptions = PhotoCaptureOptions(),
                 completion: @escaping (Result<Void, Error>) -> Void) {
        self.pendingSnapshot = snapshot
        self.pendingOverlay = overlayLayer
        self.options = options
        self.completion = completion
        session.capture(delegate: self, shutterSound: options.shutterSound,
                        heic: options.format == .heic)
    }

    // Runs on the capture session queue.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error { return finish(.failure(error)) }
        guard var data = photo.fileDataRepresentation() else {
            return finish(.failure(CaptureError.noData))
        }

        // 2. Overlay burn; the pre-burn copy backs the shared save-original setting.
        var original: Data?
        if let layer = pendingOverlay {
            if options.saveOriginal { original = data }
            data = burn(layer, into: data)
        }

        // 3. EXIF location (the original keeps it too).
        if options.exifLocation, let snapshot = pendingSnapshot {
            let gps = GPSMetadata.dictionary(from: snapshot)
            data = merge(gps: gps, into: data)
            original = original.map { merge(gps: gps, into: $0) }
        }

        // 4. Name + 5. persist into the Photos library. The `_original` marker is
        // fixed, distinct from the user's filename.suffix (camera.md step 5);
        // the copy is best-effort and never fails the capture.
        let ext = fileExtension(of: data)
        let date = Date()
        let name = filename.makeName(for: date, snapshot: pendingSnapshot) {
            store.existingBaseNames().contains($0)
        }
        if let original {
            store.save(photo: original, name: name + "_original", ext: ext, date: date) { _ in }
        }
        store.save(photo: data, name: name, ext: ext, date: date) { [self] result in
            finish(result)
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        let completion = completion
        self.completion = nil
        DispatchQueue.main.async { completion?(result) }
    }

    /// Extension matching the encoded bytes, not the requested format: a HEIC
    /// request falls back to JPEG on hardware without HEVC, and the saved
    /// name must match the data.
    private func fileExtension(of data: Data) -> String {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(src) as String? else {
            return options.format.ext
        }
        return uti == UTType.heic.identifier ? "heic" : "jpg"
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
        let encoded = options.format == .heic ? burned.heicData()
                                              : burned.jpegData(compressionQuality: 0.95)
        guard let encoded else { return data }
        // The draw baked the pixels upright; drop the stale orientation + dims.
        var props = properties(of: data)
        props[kCGImagePropertyOrientation as String] = nil
        props[kCGImagePropertyPixelWidth as String] = nil
        props[kCGImagePropertyPixelHeight as String] = nil
        if var tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff[kCGImagePropertyTIFFOrientation as String] = nil
            props[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        return reencode(encoded, applying: props)
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
