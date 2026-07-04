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
/// persists into the shared `CaptureStore`.
/// `nonisolated`: the recording delegate fires on the capture session queue.
nonisolated final class VideoCaptureService: NSObject, AVCaptureFileOutputRecordingDelegate {
    // TODO: read from SettingsStore once the settings framework lands.
    var exifLocation = true   // camera.exif.location
    var saveToPhotos = true   // camera.saveToPhotos

    private let filename: FilenameProviding
    private let store = CaptureStore()
    private let ext = "mov"   // TODO: camera.video format
    private var completion: ((Result<URL, Error>) -> Void)?

    init(filename: FilenameProviding) {
        self.filename = filename
    }

    /// `snapshot` is captured by the caller at record start (nil = no fix / EXIF off).
    func startRecording(with session: CameraSession,
                        snapshot: LocationSnapshot?,
                        completion: @escaping (Result<URL, Error>) -> Void) {
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
        guard exifLocation, let snapshot else { return [] }
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
        if let error {
            try? FileManager.default.removeItem(at: outputFileURL)
            return finish(.failure(error))
        }

        // 4. Name + 5. persist (app-private, atomic move).
        let name = filename.makeName(for: Date()) { store.existingBaseNames().contains($0) }
        let url: URL
        do {
            url = try store.moveIn(from: outputFileURL, name: name, ext: ext)
        } catch {
            return finish(.failure(error))
        }

        // 6. Copy to Camera Roll (add-only) when enabled.
        if saveToPhotos { CameraRoll.copy(url, as: .video) }

        // 7. TODO: usage metrics (video count) -> monetization interstitial.

        finish(.success(url))
    }

    private func finish(_ result: Result<URL, Error>) {
        let completion = completion
        self.completion = nil
        DispatchQueue.main.async { completion?(result) }
    }
}
