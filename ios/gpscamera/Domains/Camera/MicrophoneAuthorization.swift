import AVFoundation

/// Collapses `AVCaptureDevice` audio authorization into the shared
/// `PermissionStatus` and requests access. Used only in video mode — the mic is
/// never touched during photo capture (camera.md "Audio").
nonisolated enum MicrophoneAuthorization {
    static var status: PermissionStatus {
        map(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    static func request(_ completion: @escaping (PermissionStatus) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted ? .authorized : .denied)
        }
    }

    static func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:           return .authorized
        case .denied, .restricted:  return .denied
        default:                    return .notDetermined
        }
    }
}
