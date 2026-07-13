//
//  OnboardingModel.swift
//  Onboarding - drives the first-run flow (onboarding.md "Flow").
//

import Combine
import Foundation

@MainActor
final class OnboardingModel: ObservableObject {
    enum Step { case value, permissions }

    @Published private(set) var step: Step = .value
    /// Permission results shown on the permissions page (nil = not asked yet).
    @Published private(set) var locationGranted: Bool?
    @Published private(set) var cameraGranted: Bool?
    @Published private(set) var photosGranted: Bool?
    @Published private(set) var requesting = false

    /// Set by the root gate to flip to Main when the flow finishes.
    var onComplete: () -> Void = {}

    private let location: LocationProviding
    private let requestCamera: (@escaping (PermissionStatus) -> Void) -> Void
    private let requestPhotos: (@escaping (PermissionStatus) -> Void) -> Void
    private let store: SettingsStore
    private let events: EventTracking
    private var started = false

    init(location: LocationProviding,
         requestCamera: @escaping (@escaping (PermissionStatus) -> Void) -> Void
            = { CameraAuthorization.request($0) },
         requestPhotos: @escaping (@escaping (PermissionStatus) -> Void) -> Void
            = { PhotoLibraryAuthorization.request($0) },
         store: SettingsStore,
         events: EventTracking) {
        self.location = location
        self.requestCamera = requestCamera
        self.requestPhotos = requestPhotos
        self.store = store
        self.events = events
    }

    /// Fired when the flow first appears (not at construction: the model is
    /// built every launch, but returning users never see onboarding).
    func start() {
        guard !started else { return }
        started = true
        events.track(.onboardingStarted)
    }

    /// "Continue" on the value page.
    func next() {
        switch step {
        case .value: step = .permissions
        case .permissions: break   // the permissions page uses `requestPermissions`
        }
    }

    /// Permissions page "Enable": request location, then camera, then photos.
    /// Each request starts only after the previous choice resolves. Non-blocking
    /// - advances to Main either way. The mic is requested on first recording.
    func requestPermissions() {
        guard !requesting else { return }
        requesting = true
        location.requestPermission { [weak self] locationStatus in
            Task { @MainActor in
                guard let self else { return }
                self.requestCamera { [weak self] cameraStatus in
                    self?.requestPhotos { photosStatus in
                        Task { @MainActor in
                            self?.finish(locationStatus: locationStatus,
                                         cameraStatus: cameraStatus,
                                         photosStatus: photosStatus)
                        }
                    }
                }
            }
        }
    }

    private func finish(locationStatus: PermissionStatus, cameraStatus: PermissionStatus,
                        photosStatus: PermissionStatus) {
        locationGranted = locationStatus == .authorized
        cameraGranted = cameraStatus == .authorized
        photosGranted = photosStatus == .authorized
        events.track(.onboardingPermission(type: .location, granted: locationGranted ?? false))
        events.track(.onboardingPermission(type: .camera, granted: cameraGranted ?? false))
        events.track(.onboardingPermission(type: .photos, granted: photosGranted ?? false))
        complete()
    }

    private func complete() {
        store.set(.bool(true), for: Onboarding.completedKey)
        events.track(.onboardingCompleted)
        onComplete()
    }
}
