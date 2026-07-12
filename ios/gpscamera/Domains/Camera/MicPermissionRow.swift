//
//  MicPermissionRow.swift
//  Camera - Video-section settings row for the mic (camera.md "Audio"). Shows
//  the current authorization; a denied mic still records silent video. Tapping
//  requests the mic when undetermined, or opens iOS Settings when denied.
//

import SwiftUI

struct MicPermissionRow: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var status = MicrophoneAuthorization.status

    var body: some View {
        Button(action: tap) {
            LabeledContent(L("Microphone")) {
                HStack(spacing: 6) {
                    Text(L(statusLabel)).foregroundStyle(.secondary)
                    if status != .authorized {
                        Image(systemName: "chevron.forward")
                            .font(.caption.bold()).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(status == .authorized)
        // Re-read on return from iOS Settings so a fresh grant/deny shows.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { status = MicrophoneAuthorization.status }
        }
    }

    private var statusLabel: String {
        switch status {
        case .authorized:   "Granted"
        case .denied:       "Denied"
        case .notDetermined: "Not set"
        }
    }

    private func tap() {
        switch status {
        case .authorized:
            break
        case .notDetermined:
            MicrophoneAuthorization.request { new in
                DispatchQueue.main.async { status = new }
            }
        case .denied:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}
