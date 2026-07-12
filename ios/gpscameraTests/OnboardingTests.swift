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
    func requestPermission() { requested = true; authorization = grantResult }
}

@MainActor
private func makeStore() -> SettingsStore {
    let store = SettingsStore(defaults: UserDefaults(suiteName: "onboarding.test.\(UUID())")!)
    Onboarding.registerDefaults(store)
    return store
}

struct OnboardingModelTests {
    @Test @MainActor func valuePageAdvancesThenStopsAtPermissions() {
        let model = OnboardingModel(location: FakeLocation(),
                                    requestCamera: { $0(.authorized) },
                                    requestMic: { $0(.authorized) },
                                    store: makeStore(), events: NoopTracker())
        #expect(model.step == .value)
        model.next(); #expect(model.step == .permissions)
        model.next(); #expect(model.step == .permissions)   // no-op on last page
    }

    @Test @MainActor func grantingAllCompletesAndSetsFlag() async {
        let store = makeStore()
        let loc = FakeLocation()   // grants location
        var completed = false
        let model = OnboardingModel(location: loc,
                                    requestCamera: { $0(.authorized) },
                                    requestMic: { $0(.authorized) },
                                    store: store, events: NoopTracker())
        model.onComplete = { completed = true }
        model.requestPermissions()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(loc.requested)
        #expect(store.bool(Onboarding.completedKey))
        #expect(completed)
        #expect(model.locationGranted == true)
        #expect(model.cameraGranted == true)
        #expect(model.micGranted == true)
    }

    @Test @MainActor func denyingStillCompletes() async {
        let store = makeStore()
        let loc = FakeLocation(); loc.grantResult = .denied
        var completed = false
        let model = OnboardingModel(location: loc,
                                    requestCamera: { $0(.denied) },
                                    requestMic: { $0(.denied) },
                                    store: store, events: NoopTracker())
        model.onComplete = { completed = true }
        model.requestPermissions()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(store.bool(Onboarding.completedKey))   // non-blocking: still done
        #expect(completed)
        #expect(model.locationGranted == false)
        #expect(model.cameraGranted == false)
        #expect(model.micGranted == false)
    }
}
