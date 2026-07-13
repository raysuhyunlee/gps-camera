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
    /// Overlay data (location snapshot) frozen at record start so the live
    /// preview matches the burned clip while recording; nil = track live data.
    @Published private(set) var lockedOverlaySnapshot: LocationSnapshot?
    /// Last preview frame, shown blurred while the session graph rebuilds
    /// (lens / facing / mode switch) so the feed never flickers to black.
    @Published private(set) var freezeFrame: UIImage?
    /// Drives rotatable + anchored controls and the capture rotation. Frozen
    /// when `camera.orientationLock` is on or while recording (camera.md
    /// "Device Orientation").
    @Published private(set) var captureOrientation: UIDeviceOrientation = .portrait
    /// A permission the user has to resolve in iOS Settings; `CameraView` shows
    /// it as an alert (camera.md "Permissions").
    @Published var nudge: CameraNudge?

    let session = CameraSession()
    private let store: SettingsStore
    private let location: LocationProviding
    private let overlay: OverlayRendering
    private let events: EventTracking
    private let metrics: UsageMetrics
    private let photo: PhotoCaptureService
    private let video: VideoCaptureService
    private var previewTransitions = 0   // overlapping switch reconfigures
    private var appliedQuality = CaptureQuality()
    private var storeChanges: AnyCancellable?

    init(location: LocationProviding,
         overlay: OverlayRendering,
         filename: FilenameProviding,
         captures: PhotoLibraryStore,
         store: SettingsStore,
         events: EventTracking,
         metrics: UsageMetrics) {
        self.location = location
        self.overlay = overlay
        self.store = store
        self.events = events
        self.metrics = metrics
        photo = PhotoCaptureService(filename: filename, store: captures)
        video = VideoCaptureService(filename: filename, store: captures)
        authorization = CameraAuthorization.status
        #if DEBUG
        // Screenshot demo mode renders a static scene (no session); treat the
        // camera as authorized so CameraView shows the preview area.
        if ScreenshotDemo.current.isActive { authorization = .authorized }
        #endif
        // Live-apply resolution/fps edits.
        storeChanges = store.onChange { [weak self] in self?.applyQualityIfChanged() }
    }

    private var settings: CameraSettings { CameraSettings(from: store) }

    var previewSession: AVCaptureSession { session.session }

    func onAppear() {
        #if DEBUG
        if ScreenshotDemo.current.isActive {
            // Static scene; no real session. Seed the lens set so the 0.5x/1x/2x
            // selector renders (a real session would populate it from hardware).
            availableLenses = [.ultraWide, .wide, .tele]
            return
        }
        #endif
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
        self.mode = mode
        beginPreviewTransition()
        session.setMode(mode) { [weak self] in self?.endPreviewTransition() }
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
        if mode == .video, isRecording { return stopRecording() }
        // Captures go straight to the Photos library, so without it there is
        // nowhere to save (camera.md "Storage").
        guard ensurePhotoLibrary() else { return }

        switch mode {
        case .photo:
            guard !isCapturing else { return }
            isCapturing = true
            // Snapshot, overlay layer, and settings are fixed at shutter time
            // so the burn and EXIF describe the same moment.
            let snapshot = location.snapshot
            let settings = settings
            let options = PhotoCaptureOptions(
                exifLocation: CameraSettings.effectiveExifLocation(store),
                saveOriginal: settings.saveOriginal,
                format: settings.photoFormat,
                shutterSound: settings.shutterSound)
            photo.capture(with: session, snapshot: snapshot,
                          overlayLayer: overlay.renderedLayer(snapshot: snapshot),
                          options: options) { [weak self] result in
                self?.isCapturing = false
                self?.captureFinished(.photo, result: result)
            }
        case .video:
            ensureMicThenRecord()
        }
    }

    /// False when the capture cannot be saved: nudges the user to iOS Settings
    /// (denied), or raises the prompt (undetermined - onboarding normally asks,
    /// so this only covers a reset) and drops this tap.
    private func ensurePhotoLibrary() -> Bool {
        switch PhotoLibraryAuthorization.status {
        case .authorized:
            return true
        case .denied:
            nudge = .photoLibrary
            return false
        case .notDetermined:
            PhotoLibraryAuthorization.request { [weak self] status in
                DispatchQueue.main.async {
                    guard status != .authorized else { return }
                    self?.nudge = .photoLibrary
                }
            }
            return false
        }
    }

    /// The mic is requested on the first recording, not on the mode switch: the
    /// prompt belongs to the moment audio is actually needed (camera.md "Audio").
    /// A denied mic nudges once, then records silent video from then on.
    private func ensureMicThenRecord() {
        switch MicrophoneAuthorization.status {
        case .authorized:
            startRecording()
        case .notDetermined:
            MicrophoneAuthorization.request { [weak self] status in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard self.mode == .video, !self.isRecording else { return }
                    // A grant has to reach the session graph before the clip
                    // starts, or the recording is silent anyway.
                    guard status == .authorized else { return self.startRecording() }
                    self.beginPreviewTransition()
                    self.session.setMode(.video) { [weak self] in
                        DispatchQueue.main.async {
                            self?.endPreviewTransition()
                            self?.startRecording()
                        }
                    }
                }
            }
        case .denied:
            guard store.bool(CameraSettingKey.micNudged) else {
                store.set(.bool(true), for: CameraSettingKey.micNudged)
                nudge = .microphone
                return
            }
            startRecording()   // silent video (camera.md "Audio")
        }
    }

    private func startRecording() {
        let shutterSound = settings.shutterSound
        if shutterSound { AudioServicesPlaySystemSound(RecordingSound.begin) }
        isRecording = true
        let options = VideoCaptureService.Options(
            exifLocation: CameraSettings.effectiveExifLocation(store),
            saveOriginal: settings.saveOriginal)
        // Overlay data locked at record start (like the photo burn + GPS
        // metadata); the live preview reads this too, so it matches the clip.
        let snapshot = location.snapshot
        lockedOverlaySnapshot = snapshot
        video.startRecording(with: session, snapshot: snapshot,
                             overlayLayer: overlay.renderedLayer(snapshot: snapshot),
                             options: options,
                             onStopped: { [weak self] in
            guard let self else { return }
            if shutterSound { AudioServicesPlaySystemSound(RecordingSound.end) }
            isRecording = false
            lockedOverlaySnapshot = nil
            // Controls resume tracking the live orientation.
            deviceOrientationChanged(UIDevice.current.orientation)
        }, completion: { [weak self] result in
            self?.captureFinished(.video, result: result)
        })
    }

    /// Analytics + usage counters for a finished capture (event.md).
    private func captureFinished(_ kind: Event.CaptureKind, result: Result<Void, Error>) {
        switch result {
        case .success:
            events.track(.captureCompleted(kind: kind))
            kind == .photo ? metrics.recordPhotoCapture() : metrics.recordVideoCapture()
        case .failure(let error):
            events.track(.captureFailed(kind: kind, reason: Event.reason(error)))
            events.record(error, keys: ["capture_kind": kind.rawValue])
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
