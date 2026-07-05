//
//  gpscameraApp.swift
//  gpscamera
//
//  Composition root: constructs domains and wires them into screens.
//

import SwiftUI

@main
struct gpscameraApp: App {
    @StateObject private var location: LocationProvider
    @StateObject private var camera: CameraController
    private let overlay: OverlayRenderer

    init() {
        let location = LocationProvider()
        let overlay = OverlayRenderer()
        self.overlay = overlay
        _location = StateObject(wrappedValue: location)
        _camera = StateObject(wrappedValue: CameraController(location: location, overlay: overlay))
    }

    var body: some Scene {
        WindowGroup {
            CameraView(controller: camera, location: location, overlay: overlay)
        }
    }
}
