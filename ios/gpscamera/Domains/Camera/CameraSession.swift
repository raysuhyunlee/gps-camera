import AVFoundation

enum CameraFacing {
    case back, front

    var position: AVCaptureDevice.Position { self == .back ? .back : .front }
}

/// A selectable lens. `wide` is the default 1x; ultra-wide / tele appear only
/// when the hardware has them (see `CameraSession.availableLenses`).
enum Lens: CaseIterable {
    case ultraWide, wide, tele

    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide:      return .builtInWideAngleCamera
        case .tele:      return .builtInTelephotoCamera
        }
    }
}

/// Thin `AVCaptureSession` wrapper: owns the session, the photo output, and
/// device selection (facing, lens, flash). All session mutation runs on a
/// private serial queue; callers hop through the completion closures.
/// `nonisolated`: session work runs off the main actor.
nonisolated final class CameraSession {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?

    private(set) var facing: CameraFacing = .back
    private(set) var lens: Lens = .wide
    var flashMode: AVCaptureDevice.FlashMode = .off

    /// Lenses physically present for a facing, in zoom order.
    func availableLenses(for facing: CameraFacing) -> [Lens] {
        let types = Lens.allCases.map(\.deviceType)
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: .video, position: facing.position)
        let present = Set(discovery.devices.map(\.deviceType))
        return [Lens.ultraWide, .wide, .tele].filter { present.contains($0.deviceType) }
    }

    /// Build the graph for the current facing/lens. Safe to call repeatedly.
    func configure() {
        queue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .photo
            if let input { session.removeInput(input) }

            let device = resolveDevice(facing: facing, lens: lens)
            if let device, let newInput = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(newInput) {
                session.addInput(newInput)
                input = newInput
            }
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            session.commitConfiguration()
        }
    }

    func setFacing(_ facing: CameraFacing) {
        self.facing = facing
        if !availableLenses(for: facing).contains(lens) { lens = .wide }
        configure()
    }

    func setLens(_ lens: Lens) {
        guard availableLenses(for: facing).contains(lens) else { return }
        self.lens = lens
        configure()
    }

    func start() { queue.async { [self] in if !session.isRunning { session.startRunning() } } }
    func stop()  { queue.async { [self] in if session.isRunning { session.stopRunning() } } }

    func capture(delegate: AVCapturePhotoCaptureDelegate) {
        queue.async { [self] in
            let settings = AVCapturePhotoSettings()
            if photoOutput.supportedFlashModes.contains(flashMode) {
                settings.flashMode = flashMode
            }
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    /// Prefer the exact lens; fall back to the facing's default wide device.
    private func resolveDevice(facing: CameraFacing, lens: Lens) -> AVCaptureDevice? {
        AVCaptureDevice.default(lens.deviceType, for: .video, position: facing.position)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: facing.position)
    }
}
