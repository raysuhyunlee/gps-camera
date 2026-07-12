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
    @Published private(set) var micGranted: Bool?
    @Published private(set) var requesting = false

    /// Set by the root gate to flip to Main when the flow finishes.
    var onComplete: () -> Void = {}

    private let location: LocationProviding
    private let requestCamera: (@escaping (PermissionStatus) -> Void) -> Void
    private let requestMic: (@escaping (PermissionStatus) -> Void) -> Void
    private let store: SettingsStore
    private let events: EventTracking
    private var started = false

    init(location: LocationProviding,
         requestCamera: @escaping (@escaping (PermissionStatus) -> Void) -> Void
            = { CameraAuthorization.request($0) },
         requestMic: @escaping (@escaping (PermissionStatus) -> Void) -> Void
            = { MicrophoneAuthorization.request($0) },
         store: SettingsStore,
         events: EventTracking) {
        self.location = location
        self.requestCamera = requestCamera
        self.requestMic = requestMic
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

    /// Permissions page "Enable": request location, then camera, then mic. The
    /// OS serializes the dialogs; when the last resolves the earlier choices have
    /// already landed. Non-blocking - advances to Main either way. Mic is
    /// optional (denial records silent video, camera.md "Audio").
    func requestPermissions() {
        guard !requesting else { return }
        requesting = true
        if location.authorization == .notDetermined { location.requestPermission() }
        requestCamera { [weak self] cameraStatus in
            self?.requestMic { micStatus in
                Task { @MainActor in
                    self?.finish(cameraStatus: cameraStatus, micStatus: micStatus)
                }
            }
        }
    }

    private func finish(cameraStatus: PermissionStatus, micStatus: PermissionStatus) {
        locationGranted = location.authorization == .authorized
        cameraGranted = cameraStatus == .authorized
        micGranted = micStatus == .authorized
        events.track(.onboardingPermission(type: .location, granted: locationGranted ?? false))
        events.track(.onboardingPermission(type: .camera, granted: cameraGranted ?? false))
        events.track(.onboardingPermission(type: .mic, granted: micGranted ?? false))
        complete()
    }

    private func complete() {
        store.set(.bool(true), for: Onboarding.completedKey)
        events.track(.onboardingCompleted)
        onComplete()
    }
}
