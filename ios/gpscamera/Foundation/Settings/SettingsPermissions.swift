//
//  SettingsPermissions.swift
//  Foundation - OS permission checks for permission-coupled settings.
//  Platform frameworks only; never a domain (foundation.md).
//

import CoreLocation
import Photos

nonisolated enum SettingsPermissions {
    static func status(_ permission: SettingPermission) -> PermissionStatus {
        switch permission {
        case .location:
            switch CLLocationManager().authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: return .authorized
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        case .photoAddOnly:
            switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
            case .authorized, .limited: return .authorized
            case .notDetermined: return .notDetermined
            default: return .denied
            }
        }
    }

    /// Request the permission (used when the user enables a coupled item).
    /// `completion` fires on main with the post-prompt status.
    static func request(_ permission: SettingPermission,
                        completion: @escaping (PermissionStatus) -> Void) {
        switch permission {
        case .location:
            LocationPermissionRequest.begin(completion)
        case .photoAddOnly:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in
                DispatchQueue.main.async { completion(status(.photoAddOnly)) }
            }
        }
    }
}

/// Retains a CLLocationManager + delegate for the duration of one prompt
/// (the manager must outlive the system dialog).
private final class LocationPermissionRequest: NSObject, CLLocationManagerDelegate {
    private static var active: LocationPermissionRequest?
    private let manager = CLLocationManager()
    private let completion: (PermissionStatus) -> Void

    static func begin(_ completion: @escaping (PermissionStatus) -> Void) {
        let request = LocationPermissionRequest(completion)
        active = request
        request.manager.requestWhenInUseAuthorization()
    }

    private init(_ completion: @escaping (PermissionStatus) -> Void) {
        self.completion = completion
        super.init()
        manager.delegate = self
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        DispatchQueue.main.async {
            self.completion(SettingsPermissions.status(.location))
            Self.active = nil
        }
    }
}
