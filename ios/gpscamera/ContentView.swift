//
//  ContentView.swift
//  gpscamera
//
//  Debug surface for development inspection (location module, pro status).
//  Backdoor entry: tap the Settings title 7 times rapidly.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var location = LocationProvider()
    /// Pro status inspection; nil (previews) hides the section.
    var pro: ProStore?
    /// Interstitial inspection; nil (previews) hides the section.
    var ads: InterstitialAds?
    /// Usage counters inspection + manual edit; nil (previews) hides the section.
    var metrics: UsageMetrics?
    /// Onboarding flag reset; nil (previews) hides the section.
    var store: SettingsStore?

    var body: some View {
        List {
            if let pro { ProDebugSection(pro: pro) }
            if let ads { AdsDebugSection(ads: ads) }
            if let metrics { MetricsDebugSection(metrics: metrics) }
            if let store { OnboardingDebugSection(store: store) }
            Section("Authorization") {
                Text(String(describing: location.authorization))
                if location.authorization == .notDetermined {
                    Button("Request permission") { location.requestPermission() }
                }
            }
            if let s = location.snapshot {
                Section("Snapshot") {
                    row("Latitude", String(format: "%.6f", s.coordinate.latitude))
                    row("Longitude", String(format: "%.6f", s.coordinate.longitude))
                    row("Altitude", String(format: "%.1f m", s.altitude))
                    row("Accuracy", String(format: "%.1f m (%@)", s.accuracyMeters,
                                           String(describing: s.accuracyLevel)))
                    if let h = s.heading {
                        row("Heading", String(format: "%.0f\u{00B0} %@", h.degrees, h.cardinal.rawValue))
                    }
                    row("Address", s.address ?? "resolving...")
                    row("Time", s.timestamp.formatted(date: .omitted, time: .standard))
                }
            } else {
                Section { Text("Waiting for first fix...") }
            }
        }
        .onAppear {
            location.requestPermission()
            location.start()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

/// Current entitlement + a button that refetches it from RevenueCat.
private struct ProDebugSection: View {
    @ObservedObject var pro: ProStore
    @State private var refreshing = false

    var body: some View {
        Section("Pro") {
            HStack {
                Text("Entitlement")
                Spacer()
                Text(String(describing: pro.entitlement))
                    .foregroundStyle(.secondary)
            }
            Button(refreshing ? "Refreshing..." : "Refresh pro status") {
                Task {
                    refreshing = true
                    await pro.refresh()
                    refreshing = false
                }
            }
            .disabled(refreshing)
            Button("Show success modal") { PurchaseSuccess.present() }
        }
    }
}

/// Live interstitial state + manual preload/show. Note: ads never start for
/// pro - check the Pro section's entitlement when nothing loads.
private struct AdsDebugSection: View {
    @ObservedObject var ads: InterstitialAds

    var body: some View {
        Section("Ads") {
            HStack {
                Text("Interstitial")
                Spacer()
                Text(ads.isLoaded ? "loaded" : "not loaded")
                    .foregroundStyle(.secondary)
            }
            if let error = ads.lastError {
                Text("Ad error: \(error)")
                    .font(.footnote).foregroundStyle(.red)
            }
            Button("Preload interstitial") { ads.preload() }
            Button("Show interstitial") { ads.show() }
                .disabled(!ads.isLoaded)
        }
    }
}

/// Resets the onboarding flag so the first-run flow shows again on next launch
/// (RootView reads the flag at startup; onboarding.md).
private struct OnboardingDebugSection: View {
    let store: SettingsStore
    @State private var didReset = false

    var body: some View {
        Section("Onboarding") {
            HStack {
                Text("Completed")
                Spacer()
                Text(String(store.bool(Onboarding.completedKey)))
                    .foregroundStyle(.secondary)
            }
            Button("Reset onboarding") {
                store.set(.bool(false), for: Onboarding.completedKey)
                didReset = true
            }
            if didReset {
                Text("Restart the app to see it.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

/// Session/lifetime usage counters, editable in place to exercise the nudge
/// and ad rules (e.g. set photos to 24 and capture to hit the 25 milestone).
private struct MetricsDebugSection: View {
    let metrics: UsageMetrics
    /// The number pad has no return key; a keyboard-toolbar Done button ends
    /// editing (which also commits the focused field's value).
    @FocusState private var editing: Bool

    var body: some View {
        Section("Usage metrics") {
            HStack {
                Text("First installed")
                Spacer()
                Text(metrics.firstInstalledAt.formatted(
                    date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            editRow("Sessions", get: { metrics.sessionCount },
                    set: { metrics.sessionCount = $0 })
            editRow("Photos", get: { metrics.photoCaptureCount },
                    set: { metrics.photoCaptureCount = $0 })
            editRow("Videos", get: { metrics.videoCaptureCount },
                    set: { metrics.videoCaptureCount = $0 })
            editRow("Photos (session)", get: { metrics.sessionPhotoCount },
                    set: { metrics.sessionPhotoCount = $0 })
            editRow("Videos (session)", get: { metrics.sessionVideoCount },
                    set: { metrics.sessionVideoCount = $0 })
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editing = false }
            }
        }
    }

    private func editRow(_ label: String, get: @escaping () -> Int,
                         set: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: Binding(get: get, set: set), format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .foregroundStyle(.secondary)
                .focused($editing)
        }
    }
}

#Preview {
    ContentView()
}
