//
//  OnboardingTests.swift
//  Onboarding flow logic (onboarding.md): step advancement + permission finish.
//

import Testing
import Foundation
@testable import gpscamera

private final class FakeLocation: LocationProviding {
    var authorization: PermissionStatus = .notDetermined
    /// Result applied when `requestPermission()` is called.
    var grantResult: PermissionStatus = .authorized
    private(set) var requested = false
    var snapshot: LocationSnapshot? { nil }
    func start() {}
    func stop() {}
    func requestPermission(_ completion: @escaping (PermissionStatus) -> Void) {
        requested = true
        authorization = grantResult
        completion(grantResult)
    }
}

private final class ControlledLocation: LocationProviding {
    var authorization: PermissionStatus = .notDetermined
    var snapshot: LocationSnapshot? { nil }
    private var completion: ((PermissionStatus) -> Void)?

    func start() {}
    func stop() {}
    func requestPermission(_ completion: @escaping (PermissionStatus) -> Void) {
        self.completion = completion
    }
    func resolve(_ status: PermissionStatus) {
        authorization = status
        completion?(status)
        completion = nil
    }
}

@MainActor
private func makeStore() -> SettingsStore {
    let store = SettingsStore(defaults: UserDefaults(suiteName: "onboarding.test.\(UUID())")!)
    Onboarding.registerDefaults(store)
    return store
}

@MainActor
private func requestPermissionsAndWait(_ model: OnboardingModel) async {
    await withCheckedContinuation { continuation in
        model.onComplete = { continuation.resume() }
        model.requestPermissions()
    }
}

struct OnboardingModelTests {
    @Test @MainActor func permissionPromptsWaitForPreviousChoice() async {
        let location = ControlledLocation()
        var cameraCompletion: ((PermissionStatus) -> Void)?
        var photosCompletion: ((PermissionStatus) -> Void)?
        var model: OnboardingModel!

        await withCheckedContinuation { cameraRequested in
            model = OnboardingModel(
                location: location,
                requestCamera: {
                    cameraCompletion = $0
                    cameraRequested.resume()
                },
                requestPhotos: { photosCompletion = $0 },
                store: makeStore(), events: NoopTracker())

            model.requestPermissions()
            #expect(cameraCompletion == nil)
            #expect(photosCompletion == nil)
            location.resolve(.authorized)
        }
        #expect(cameraCompletion != nil)
        #expect(photosCompletion == nil)

        cameraCompletion?(.authorized)
        #expect(photosCompletion != nil)
    }

    @Test @MainActor func valuePageAdvancesThenStopsAtPermissions() {
        let model = OnboardingModel(location: FakeLocation(),
                                    requestCamera: { $0(.authorized) },
                                    requestPhotos: { $0(.authorized) },
                                    store: makeStore(), events: NoopTracker())
        #expect(model.step == .value)
        model.next(); #expect(model.step == .permissions)
        model.next(); #expect(model.step == .permissions)   // no-op on last page
    }

    @Test @MainActor func grantingAllCompletesAndSetsFlag() async {
        let store = makeStore()
        let loc = FakeLocation()   // grants location
        let model = OnboardingModel(location: loc,
                                    requestCamera: { $0(.authorized) },
                                    requestPhotos: { $0(.authorized) },
                                    store: store, events: NoopTracker())
        await requestPermissionsAndWait(model)

        #expect(loc.requested)
        #expect(store.bool(Onboarding.completedKey))
        #expect(model.locationGranted == true)
        #expect(model.cameraGranted == true)
        #expect(model.photosGranted == true)
    }

    @Test @MainActor func denyingStillCompletes() async {
        let store = makeStore()
        let loc = FakeLocation(); loc.grantResult = .denied
        let model = OnboardingModel(location: loc,
                                    requestCamera: { $0(.denied) },
                                    requestPhotos: { $0(.denied) },
                                    store: store, events: NoopTracker())
        await requestPermissionsAndWait(model)

        #expect(store.bool(Onboarding.completedKey))   // non-blocking: still done
        #expect(model.locationGranted == false)
        #expect(model.cameraGranted == false)
        #expect(model.photosGranted == false)
    }
}
