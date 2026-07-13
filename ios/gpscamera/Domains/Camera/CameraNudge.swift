//
//  CameraNudge.swift
//  Camera - a permission the capture path needs but does not have, surfaced as
//  an alert on Main with a route to iOS Settings (camera.md "Permissions").
//

import Foundation

nonisolated enum CameraNudge: Identifiable {
    /// Required to save at all: captures go straight to Photos.
    case photoLibrary
    /// Optional: recording proceeds without audio once the user has been told.
    case microphone

    var id: Self { self }

    var title: L10nKey {
        switch self {
        case .photoLibrary: "Photo access needed"
        case .microphone:   "Microphone is off"
        }
    }

    var message: L10nKey {
        switch self {
        case .photoLibrary:
            "GPS Camera saves your photos and videos to your photo library. Turn on photo access to capture."
        case .microphone:
            "Videos will record without sound. Turn on the microphone to record audio."
        }
    }
}
