//
//  ContentView.swift
//  gpscamera
//
//  Debug surface for development inspection (location module, pro status).
//  Backdoor entry: long-press (5s) the GPS status icon on Main.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var location = LocationProvider()
    /// Pro status inspection; nil (previews) hides the section.
    var pro: ProStore?

    var body: some View {
        List {
            if let pro { ProDebugSection(pro: pro) }
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

#Preview {
    ContentView()
}
