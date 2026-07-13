import AVFoundation
import Photos

/// Builds the ISO 6709 location string for QuickTime movie metadata
/// (`com.apple.quicktime.location.ISO6709`). Pure and side-effect free so it can
/// be unit tested. Mirrors `GPSMetadata` for photos.
nonisolated enum ISO6709 {
    static func string(from snapshot: LocationSnapshot) -> String {
        String(format: "%+08.4f%+09.4f%+.3f/",
               snapshot.coordinate.latitude,
               snapshot.coordinate.longitude,
               snapshot.altitude)
    }
}

/// The video capture pipeline (camera.md "Capture pipeline"), the movie
/// counterpart of `PhotoCaptureService`. Records to a temp file, then names +
/// persists into the Photos library through the shared `PhotoLibraryStore`.
/// `nonisolated`: the recording delegate fires on the capture session queue.
nonisolated final class VideoCaptureService: NSObject, AVCaptureFileOutputRecordingDelegate {
    /// Settings snapshot for one recording, resolved by the controller at
    /// record start (permission-coupled values already effective).
    struct Options {
        var exifLocation = true   // camera.exif.location (effective)
        var saveOriginal = false  // camera.photo.saveOriginal (shared)
    }

    private let filename: FilenameProviding
    private let store: PhotoLibraryStore
    private let ext = "mov"
    private var options = Options()
    private var pendingSnapshot: LocationSnapshot?
    private var pendingOverlay: RenderedOverlay?
    private var onStopped: (() -> Void)?
    private var completion: ((Result<Void, Error>) -> Void)?

    init(filename: FilenameProviding, store: PhotoLibraryStore) {
        self.filename = filename
        self.store = store
    }

    /// `snapshot` is captured by the caller at record start (nil = no fix / EXIF off).
    /// `overlayLayer` is the overlay rasterized at record start (nil = overlay off);
    /// burned into the finished clip (camera.md pipeline step 2).
    /// `onStopped` fires when the clip is finalized (UI leaves the recording
    /// state); `completion` fires later, after the burn + persist finish.
    func startRecording(with session: CameraSession,
                        snapshot: LocationSnapshot?,
                        overlayLayer: RenderedOverlay? = nil,
                        options: Options = Options(),
                        onStopped: @escaping () -> Void,
                        completion: @escaping (Result<Void, Error>) -> Void) {
        self.options = options
        self.pendingSnapshot = snapshot
        self.pendingOverlay = overlayLayer
        self.onStopped = onStopped
        self.completion = completion
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        session.startRecording(to: temp,
                               metadata: locationMetadata(from: snapshot),
                               delegate: self)
    }

    func stopRecording(with session: CameraSession) {
        session.stopRecording()
    }

    // 3. EXIF location -> movie metadata (skipped when off / no fix).
    private func locationMetadata(from snapshot: LocationSnapshot?) -> [AVMetadataItem] {
        guard options.exifLocation, let snapshot else { return [] }
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataLocationISO6709
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        item.value = ISO6709.string(from: snapshot) as NSString
        return [item]
    }

    // Runs on the capture session queue.
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        // Detach this recording's state before the UI can start another one.
        let snapshot = pendingSnapshot
        let overlay = pendingOverlay
        let saveOriginal = options.saveOriginal
        let completion = completion
        self.completion = nil

        // Recording is done: leave the UI recording state now, before the
        // (potentially slow) burn + persist run in the background.
        let onStopped = onStopped
        self.onStopped = nil
        DispatchQueue.main.async { onStopped?() }

        if let error {
            try? FileManager.default.removeItem(at: outputFileURL)
            return finish(.failure(error), completion: completion)
        }

        // 2. Overlay burn: composite onto the finished clip, then persist the
        // burned copy. A composite failure falls back to the raw clip so the
        // recording is never lost (like the photo burn's encode fallback).
        guard let overlay else {
            return persist(outputFileURL, snapshot: snapshot, completion: completion)
        }
        let burned = outputFileURL.deletingPathExtension()
            .appendingPathExtension("burned").appendingPathExtension(ext)
        VideoOverlayCompositor.burn(overlay, from: outputFileURL, to: burned) { [self] result in
            switch result {
            case .success(let composited):
                if saveOriginal {
                    persist(composited, snapshot: snapshot,
                            originalFileURL: outputFileURL, completion: completion)
                } else {
                    try? FileManager.default.removeItem(at: outputFileURL)
                    persist(composited, snapshot: snapshot, completion: completion)
                }
            case .failure:
                persist(outputFileURL, snapshot: snapshot, completion: completion)
            }
        }
    }

    /// 4. Name + 5. persist into the Photos library (the temp clip is moved in).
    private func persist(_ fileURL: URL, snapshot: LocationSnapshot?,
                         originalFileURL: URL? = nil,
                         completion: ((Result<Void, Error>) -> Void)?) {
        let date = Date()
        let name = filename.makeName(for: date, snapshot: snapshot) {
            store.existingBaseNames().contains($0)
        }
        if let originalFileURL {
            store.save(video: originalFileURL, name: name + "_original", ext: ext,
                       date: date) { _ in }
        }
        store.save(video: fileURL, name: name, ext: ext, date: date) { [self] result in
            finish(result, completion: completion)
        }
    }

    private func finish(_ result: Result<Void, Error>,
                        completion: ((Result<Void, Error>) -> Void)?) {
        DispatchQueue.main.async { completion?(result) }
    }
}
