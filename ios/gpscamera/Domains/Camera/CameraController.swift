import AVFoundation
import Combine

/// Orchestrates the Main-screen camera: owns the session + capture pipeline and
/// exposes the state `CameraView` binds to. Consumes `location` for the GPS
/// indicator and EXIF; `filename` for output names.
@MainActor
final class CameraController: ObservableObject {
    enum Mode { case photo, video }   // video disabled this increment

    @Published private(set) var authorization: PermissionStatus
    @Published private(set) var availableLenses: [Lens] = []
    @Published var mode: Mode = .photo
    @Published private(set) var facing: CameraFacing = .back
    @Published private(set) var lens: Lens = .wide
    @Published private(set) var flashOn = false
    @Published private(set) var isCapturing = false

    let session = CameraSession()
    private let location: LocationProviding
    private let capture: PhotoCaptureService

    init(location: LocationProviding,
         filename: FilenameProviding = DefaultFilenameProvider()) {
        self.location = location
        capture = PhotoCaptureService(filename: filename)
        authorization = CameraAuthorization.status
    }

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
        session.configure()
        session.start()
    }

    func toggleFacing() {
        facing = facing == .back ? .front : .back
        session.setFacing(facing)
        availableLenses = session.availableLenses(for: facing)
        lens = session.lens
    }

    func selectLens(_ lens: Lens) {
        session.setLens(lens)
        self.lens = session.lens
    }

    func toggleFlash() {
        flashOn.toggle()
        session.flashMode = flashOn ? .on : .off
    }

    func shutter() {
        guard mode == .photo, !isCapturing else { return }
        isCapturing = true
        capture.capture(with: session, snapshot: location.snapshot) { [weak self] _ in
            self?.isCapturing = false
        }
    }
}
