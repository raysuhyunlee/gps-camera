//
//  ContentView.swift
//  gpscamera
//
//  Temporary debug surface for the location module.
//  Replaced by the Main screen (camera + overlay) once those domains land.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var location = LocationProvider()

    var body: some View {
        List {
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

#Preview {
    ContentView()
}
