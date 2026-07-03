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

    init() {
        let location = LocationProvider()
        _location = StateObject(wrappedValue: location)
        _camera = StateObject(wrappedValue: CameraController(location: location))
    }

    var body: some Scene {
        WindowGroup {
            CameraView(controller: camera, location: location)
        }
    }
}
