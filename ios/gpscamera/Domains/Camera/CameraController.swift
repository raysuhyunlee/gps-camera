import AudioToolbox
import AVFoundation
import Combine
import UIKit

/// Orchestrates the Main-screen camera: owns the session + capture pipelines and
/// exposes the state `CameraView` binds to. Consumes `location` for the GPS
/// indicator and EXIF; `filename` for output names; `overlay` for the burn.
@MainActor
final class CameraController: ObservableObject {
    @Published private(set) var authorization: PermissionStatus
    @Published private(set) var availableLenses: [Lens] = []
    @Published private(set) var mode: CameraMode = .photo
    @Published private(set) var facing: CameraFacing = .back
    @Published private(set) var lens: Lens = .wide
    @Published private(set) var flashOn = false
    @Published private(set) var isCapturing = false
    @Published private(set) var isRecording = false
    /// Last preview frame, shown blurred while the session graph rebuilds
    /// (lens / facing / mode switch) so the feed never flickers to black.
    @Published private(set) var freezeFrame: UIImage?
    /// Drives rotatable + anchored controls and the capture rotation. Frozen
    /// when `camera.orientationLock` is on or while recording (camera.md
    /// "Device Orientation").
    @Published private(set) var captureOrientation: UIDeviceOrientation = .portrait

    let session = CameraSession()
    private let store: SettingsStore
    private let location: LocationProviding
    private let overlay: OverlayRendering
    private let photo: PhotoCaptureService
    private let video: VideoCaptureService
    private var previewTransitions = 0   // overlapping switch reconfigures
    private var appliedQuality = CaptureQuality()
    private var storeChanges: AnyCancellable?

    init(location: LocationProviding,
         overlay: OverlayRendering,
         filename: FilenameProviding,
         store: SettingsStore) {
        self.location = location
        self.overlay = overlay
        self.store = store
        photo = PhotoCaptureService(filename: filename)
        video = VideoCaptureService(filename: filename)
        authorization = CameraAuthorization.status
        // Live-apply resolution/fps edits; main.async so the store value is
        // already written when we read it (objectWillChange fires pre-write).
        storeChanges = store.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.applyQualityIfChanged() }
        }
    }

    private var settings: CameraSettings { CameraSettings(from: store) }

    var previewSession: AVCaptureSession { session.session }

    func onAppear() {
        switch authorization {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            CameraAuthorization.request { [weak self] status in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.authorization = status
                    if status == .authorized { self.configureAndStart() }
                }
            }
        case .denied:
            break   // view shows a denied state
        }
    }

    func onDisappear() { session.stop() }

    private func configureAndStart() {
        availableLenses = session.availableLenses(for: facing)
        appliedQuality = settings.quality
        session.setQuality(appliedQuality)
        session.configure()
        session.setCaptureRotation(CameraOrientation.videoRotationAngle(for: captureOrientation))
        session.start()
    }

    /// Resolution/fps edits rebuild the session graph (behind the freeze-blur).
    private func applyQualityIfChanged() {
        let quality = settings.quality
        guard quality != appliedQuality, authorization == .authorized, !isRecording
        else { return }
        appliedQuality = quality
        session.setQuality(quality)
        beginPreviewTransition()
        session.configure { [weak self] in self?.endPreviewTransition() }
    }

    func toggleFacing() {
        guard !isRecording else { return }   // input changes are blocked mid-recording
        facing = facing == .back ? .front : .back
        beginPreviewTransition()
        session.setFacing(facing) { [weak self] in self?.endPreviewTransition() }
        availableLenses = session.availableLenses(for: facing)
        lens = session.lens
    }

    func selectLens(_ lens: Lens) {
        guard !isRecording else { return }
        beginPreviewTransition()
        session.setLens(lens) { [weak self] in self?.endPreviewTransition() }
        self.lens = session.lens
    }

    func toggleFlash() {
        flashOn.toggle()
        session.flashMode = flashOn ? .on : .off
    }

    func setMode(_ mode: CameraMode) {
        guard !isRecording, mode != self.mode else { return }
        if mode == .video { ensureMicPermission() }
        self.mode = mode
        beginPreviewTransition()
        session.setMode(mode) { [weak self] in self?.endPreviewTransition() }
    }

    /// Requests the mic lazily on first video use; re-configures to attach the
    /// input once granted. Denial still records silent video (camera.md "Audio").
    private func ensureMicPermission() {
        guard MicrophoneAuthorization.status == .notDetermined else { return }
        MicrophoneAuthorization.request { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.mode == .video else { return }
                self.beginPreviewTransition()
                self.session.setMode(.video) { [weak self] in self?.endPreviewTransition() }
            }
        }
    }

    /// Freeze the last frame (view blurs it) until the new graph delivers.
    private func beginPreviewTransition() {
        previewTransitions += 1
        if freezeFrame == nil { freezeFrame = session.latestFrame() }
    }

    /// Grace delay lets the first new frames land before the blur fades out.
    private func endPreviewTransition() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else { return }
            previewTransitions = max(0, previewTransitions - 1)
            if previewTransitions == 0 { freezeFrame = nil }
        }
    }

    func shutter() {
        switch mode {
        case .photo:
            guard !isCapturing else { return }
            isCapturing = true
            // Snapshot, overlay layer, and settings are fixed at shutter time
            // so the burn and EXIF describe the same moment. Video burn: deferred.
            let snapshot = location.snapshot
            let settings = settings
            let options = PhotoCaptureOptions(
                exifLocation: CameraSettings.effectiveExifLocation(store),
                saveToPhotos: CameraSettings.effectiveSaveToPhotos(store),
                saveOriginal: settings.saveOriginal,
                format: settings.photoFormat,
                shutterSound: settings.shutterSound)
            photo.capture(with: session, snapshot: snapshot,
                          overlayLayer: overlay.renderedLayer(snapshot: snapshot),
                          options: options) { [weak self] _ in
                self?.isCapturing = false
            }
        case .video:
            isRecording ? stopRecording() : startRecording()
        }
    }

    private func startRecording() {
        let shutterSound = settings.shutterSound
        if shutterSound { AudioServicesPlaySystemSound(RecordingSound.begin) }
        isRecording = true
        let options = VideoCaptureService.Options(
            exifLocation: CameraSettings.effectiveExifLocation(store),
            saveToPhotos: CameraSettings.effectiveSaveToPhotos(store))
        video.startRecording(with: session, snapshot: location.snapshot,
                             options: options) { [weak self] _ in
            guard let self else { return }
            if shutterSound { AudioServicesPlaySystemSound(RecordingSound.end) }
            isRecording = false
            // Controls resume tracking the live orientation.
            deviceOrientationChanged(UIDevice.current.orientation)
        }
    }

    private func stopRecording() {
        video.stopRecording(with: session)   // isRecording clears in the completion
    }

    /// The system's video record start/stop sounds (what the native camera plays).
    private enum RecordingSound {
        static let begin: SystemSoundID = 1117
        static let end: SystemSoundID = 1118
    }

    /// Fed by `CameraView` on device rotation. All control rotation and the
    /// capture rotation freeze while recording (at the orientation recording
    /// started with) and when `orientationLock` is on.
    func deviceOrientationChanged(_ orientation: UIDeviceOrientation) {
        guard orientation.isValidInterfaceOrientation,
              !store.bool(CameraSettingKey.orientationLock), !isRecording
        else { return }
        captureOrientation = orientation
        session.setCaptureRotation(CameraOrientation.videoRotationAngle(for: orientation))
    }
}
