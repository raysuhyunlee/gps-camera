//
//  RootView.swift
//  Composition-root gate (onboarding.md): the first-run flow on first launch,
//  then Main. Onboarding requests camera + location before Main mounts, so the
//  OS prompts never appear cold.
//

import SwiftUI

struct RootView<Main: View>: View {
    @StateObject private var onboarding: OnboardingModel
    @State private var onboarded: Bool
    private let main: Main

    init(store: SettingsStore, location: LocationProviding, events: EventTracking,
         @ViewBuilder main: () -> Main) {
        _onboarded = State(initialValue: store.bool(Onboarding.completedKey))
        _onboarding = StateObject(wrappedValue: OnboardingModel(
            location: location, store: store, events: events))
        self.main = main()
    }

    var body: some View {
        Group {
            if onboarded {
                main
            } else {
                OnboardingView(model: onboarding)
            }
        }
        // Bound here (not in init) so the callback can flip this view's state.
        .onAppear { onboarding.onComplete = { withAnimation { onboarded = true } } }
    }
}
