import AVFoundation
import CoreImage
import UIKit

nonisolated enum CameraFacing {
    case back, front

    var position: AVCaptureDevice.Position { self == .back ? .back : .front }
}

/// Capture mode. Photo never configures audio (music keeps playing); video
/// attaches the mic + movie output (camera.md "Audio").
nonisolated enum CameraMode { case photo, video }

/// A selectable lens. `wide` is the default 1x; ultra-wide / tele appear only
/// when the hardware has them (see `CameraSession.availableLenses`).
nonisolated enum Lens: CaseIterable {
    case ultraWide, wide, tele

    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide:      return .builtInWideAngleCamera
        case .tele:      return .builtInTelephotoCamera
        }
    }
}

/// Thin `AVCaptureSession` wrapper: owns the session, the photo + movie outputs,
/// and device selection (facing, lens, flash, mode). All session mutation runs on
/// a private serial queue; callers hop through the completion closures.
/// `nonisolated`: session work runs off the main actor.
nonisolated final class CameraSession {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let frameOutput = AVCaptureVideoDataOutput()
    private let frameStore = LatestFrameStore()
    private let frameQueue = DispatchQueue(label: "camera.session.frames")
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?

    private(set) var facing: CameraFacing = .back
    private(set) var lens: Lens = .wide
    private(set) var mode: CameraMode = .photo
    var flashMode: AVCaptureDevice.FlashMode = .off
    private var rotationAngle: CGFloat = 90   // portrait; updated per orientation
    private var quality = CaptureQuality()    // from camera.*.resolution / fps

    /// Lenses physically present for a facing, in zoom order.
    func availableLenses(for facing: CameraFacing) -> [Lens] {
        let types = Lens.allCases.map(\.deviceType)
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: facing.position)
        let present = Set(discovery.devices.map(\.deviceType))
        return [Lens.ultraWide, .wide, .tele].filter { present.contains($0.deviceType) }
    }

    /// Build the graph for the current facing/lens/mode. Safe to call repeatedly.
    /// `completion` fires on main after the new graph is committed.
    func configure(completion: (() -> Void)? = nil) {
        queue.async { [self] in
            session.beginConfiguration()
            let preset = mode == .video ? quality.videoPreset : .photo
            session.sessionPreset = session.canSetSessionPreset(preset) ? preset
                : (mode == .video ? .high : .photo)
            if let videoInput { session.removeInput(videoInput) }

            let device = resolveDevice(facing: facing, lens: lens)
            if let device, let newInput = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(newInput) {
                session.addInput(newInput)
                videoInput = newInput
            }
            if !session.outputs.contains(where: { $0 === photoOutput }),
               session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            configureFrameOutput()
            configureAudio()
            configureMovieOutput()
            if let device { configureFrameRate(device) }
            configurePhotoDimensions()
            configureFrameStyle()
            session.commitConfiguration()
            if let completion { DispatchQueue.main.async(execute: completion) }
        }
    }

    func setMode(_ mode: CameraMode, completion: (() -> Void)? = nil) {
        self.mode = mode
        configure(completion: completion)
    }

    func setFacing(_ facing: CameraFacing, completion: (() -> Void)? = nil) {
        self.facing = facing
        if !availableLenses(for: facing).contains(lens) { lens = .wide }
        configure(completion: completion)
    }

    func setLens(_ lens: Lens, completion: (() -> Void)? = nil) {
        guard availableLenses(for: facing).contains(lens) else { return }
        self.lens = lens
        configure(completion: completion)
    }

    /// Most recent preview frame - frozen (blurred) by the UI while the graph
    /// is rebuilt, so switches never flicker to black.
    func latestFrame() -> UIImage? { frameStore.latestImage }

    /// Resolution presets + fps from settings; takes effect on the next
    /// `configure` (callers reconfigure when it changes).
    func setQuality(_ quality: CaptureQuality) {
        queue.async { [self] in self.quality = quality }
    }

    /// Rotation the next capture bakes in (camera.md "Device Orientation").
    /// Stored only - connections are set lazily at capture/record time, because
    /// mutating a running connection stalls the pipeline and flickers the preview.
    func setCaptureRotation(_ angle: CGFloat) {
        queue.async { [self] in rotationAngle = angle }
    }

    func start() { queue.async { [self] in if !session.isRunning { session.startRunning() } } }
    func stop()  { queue.async { [self] in if session.isRunning { session.stopRunning() } } }

    /// `shutterSound: false` suppresses the system shutter sound where allowed
    /// (best-effort: some regions, e.g. JP/KR, force it).
    /// `heic: true` captures HEVC/HEIC when the hardware supports it.
    func capture(delegate: AVCapturePhotoCaptureDelegate,
                 shutterSound: Bool = true,
                 heic: Bool = false) {
        queue.async { [self] in
            apply(rotationAngle, to: photoOutput)
            let settings: AVCapturePhotoSettings
            if heic, photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            } else {
                settings = AVCapturePhotoSettings()
            }
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            if photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
            if !shutterSound, photoOutput.isShutterSoundSuppressionSupported {
                settings.isShutterSoundSuppressionEnabled = true
            }
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    /// `metadata` carries GPS (camera.md pipeline step 3); nil-safe empty list.
    func startRecording(to url: URL,
                        metadata: [AVMetadataItem],
                        delegate: AVCaptureFileOutputRecordingDelegate) {
        queue.async { [self] in
            guard mode == .video, !movieOutput.isRecording else { return }
            apply(rotationAngle, to: movieOutput)   // fixed for the whole clip
            movieOutput.metadata = metadata
            movieOutput.startRecording(to: url, recordingDelegate: delegate)
        }
    }

    func stopRecording() {
        queue.async { [self] in if movieOutput.isRecording { movieOutput.stopRecording() } }
    }

    // MARK: - Graph helpers (all run on `queue`)

    /// Mic attached only in video mode, and only when already authorized - a
    /// denied mic still records silent video (camera.md permission-coupled policy).
    private func configureAudio() {
        if let audioInput { session.removeInput(audioInput); self.audioInput = nil }
        guard mode == .video, MicrophoneAuthorization.status == .authorized,
              let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        audioInput = input
    }

    private func configureMovieOutput() {
        let attached = session.outputs.contains { $0 === movieOutput }
        if mode == .video, !attached, session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        } else if mode == .photo, attached {
            session.removeOutput(movieOutput)
        }
    }

    /// Feeds `frameStore` with the live frames backing the freeze transition.
    private func configureFrameOutput() {
        guard !session.outputs.contains(where: { $0 === frameOutput }),
              session.canAddOutput(frameOutput) else { return }
        frameOutput.videoSettings =
            [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        frameOutput.alwaysDiscardsLateVideoFrames = true
        frameOutput.setSampleBufferDelegate(frameStore, queue: frameQueue)
        session.addOutput(frameOutput)
    }

    /// camera.photo.resolution: the largest supported size not exceeding the
    /// chosen one (nil / device swap -> largest available). Must re-run every
    /// configure: the active format owns the supported list.
    private func configurePhotoDimensions() {
        guard let device = videoInput?.device else { return }
        let supported = device.activeFormat.supportedMaxPhotoDimensions
            .sorted { Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height) }
        guard let largest = supported.last else { return }
        if let target = quality.photo {
            photoOutput.maxPhotoDimensions = supported.last {
                Int64($0.width) * Int64($0.height) <= target.area
            } ?? largest
        } else {
            photoOutput.maxPhotoDimensions = largest
        }
    }

    /// camera.video.fps, best-effort: falls back to 30 when the active format
    /// cannot reach the requested rate.
    private func configureFrameRate(_ device: AVCaptureDevice) {
        guard mode == .video, (try? device.lockForConfiguration()) != nil else { return }
        let supported = device.activeFormat.videoSupportedFrameRateRanges
            .contains { Int($0.maxFrameRate) >= quality.fps }
        let fps = CMTime(value: 1, timescale: CMTimeScale(supported ? quality.fps : 30))
        device.activeVideoMinFrameDuration = fps
        device.activeVideoMaxFrameDuration = fps
        device.unlockForConfiguration()
    }

    private func apply(_ angle: CGFloat, to output: AVCaptureOutput) {
        guard let connection = output.connection(with: .video),
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    /// The frozen frame mimics the preview layer, which is always portrait and
    /// mirrors the front camera - independent of device orientation. Set only
    /// here, inside begin/commitConfiguration, never on the live graph.
    private func configureFrameStyle() {
        apply(90, to: frameOutput)
        guard let connection = frameOutput.connection(with: .video),
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = facing == .front
    }

    /// Prefer the exact lens; fall back to the facing's default wide device.
    private func resolveDevice(facing: CameraFacing, lens: Lens) -> AVCaptureDevice? {
        AVCaptureDevice.default(lens.deviceType, for: .video, position: facing.position)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: facing.position)
    }
}

/// Retains the most recent preview frame; `latestImage` converts it on demand
/// for the freeze-blur transition (the preview layer cannot be snapshotted).
private nonisolated final class LatestFrameStore: NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate {
    private static let context = CIContext()
    private let lock = NSLock()
    private var buffer: CVPixelBuffer?

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        lock.lock()
        buffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        lock.unlock()
    }

    var latestImage: UIImage? {
        lock.lock()
        let buffer = buffer
        lock.unlock()
        guard let buffer else { return nil }
        let image = CIImage(cvPixelBuffer: buffer)
        guard let cg = Self.context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
