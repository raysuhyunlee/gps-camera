//
//  PhotoLibraryAuthorization.swift
//  Camera - photo-library permission -> PermissionStatus. Captures are saved
//  straight to Photos, so this is required to capture at all (camera.md
//  "Permissions"). `limited` counts as authorized: assets the app creates are
//  added to the user's limited selection automatically, so the gallery still
//  sees every capture.
//

import Photos

nonisolated enum PhotoLibraryAuthorization {
    static var status: PermissionStatus {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    static func request(_ completion: @escaping (PermissionStatus) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in completion(status) }
    }
}
