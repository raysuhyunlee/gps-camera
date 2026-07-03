import AVFoundation

/// Collapses `AVCaptureDevice` video authorization into the shared
/// `PermissionStatus` and requests access.
nonisolated enum CameraAuthorization {
    static var status: PermissionStatus {
        map(AVCaptureDevice.authorizationStatus(for: .video))
    }

    static func request(_ completion: @escaping (PermissionStatus) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
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
