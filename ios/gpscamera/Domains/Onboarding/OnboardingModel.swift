//
//  OnboardingModel.swift
//  Onboarding - drives the first-run flow (onboarding.md "Flow").
//

import Combine
import Foundation

@MainActor
final class OnboardingModel: ObservableObject {
    enum Step { case hook, report, permissions }

    @Published private(set) var step: Step = .hook
    /// Permission results shown on the permissions page (nil = not asked yet).
    @Published private(set) var locationGranted: Bool?
    @Published private(set) var cameraGranted: Bool?
    @Published private(set) var requesting = false

    /// Set by the root gate to flip to Main when the flow finishes.
    var onComplete: () -> Void = {}

    private let location: LocationProviding
    private let requestCamera: (@escaping (PermissionStatus) -> Void) -> Void
    private let store: SettingsStore
    private let events: EventTracking
    private var started = false

    init(location: LocationProviding,
         requestCamera: @escaping (@escaping (PermissionStatus) -> Void) -> Void
            = { CameraAuthorization.request($0) },
         store: SettingsStore,
         events: EventTracking) {
        self.location = location
        self.requestCamera = requestCamera
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

    /// "Continue" on a value page.
    func next() {
        switch step {
        case .hook: step = .report
        case .report: step = .permissions
        case .permissions: break   // the permissions page uses `requestPermissions`
        }
    }

    /// Permissions page "Enable": request location, then camera. The OS
    /// serializes the two dialogs; when the camera dialog resolves the location
    /// choice has already landed. Non-blocking - advances to Main either way.
    func requestPermissions() {
        guard !requesting else { return }
        requesting = true
        if location.authorization == .notDetermined { location.requestPermission() }
        requestCamera { [weak self] cameraStatus in
            Task { @MainActor in self?.finish(cameraStatus: cameraStatus) }
        }
    }

    private func finish(cameraStatus: PermissionStatus) {
        locationGranted = location.authorization == .authorized
        cameraGranted = cameraStatus == .authorized
        events.track(.onboardingPermission(type: .location, granted: locationGranted ?? false))
        events.track(.onboardingPermission(type: .camera, granted: cameraGranted ?? false))
        complete()
    }

    private func complete() {
        store.set(.bool(true), for: Onboarding.completedKey)
        events.track(.onboardingCompleted)
        onComplete()
    }
}
