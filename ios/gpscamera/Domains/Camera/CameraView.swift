import SwiftUI

/// The Main screen: live camera preview hosting the GPS indicator (from
/// `location`) and the capture controls. Overlay + pro banner slot in later.
struct CameraView: View {
    @ObservedObject var controller: CameraController
    @ObservedObject var location: LocationProvider

    @State private var orientation = UIDevice.current.orientation

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch controller.authorization {
            case .authorized:
                CameraPreview(session: controller.previewSession).ignoresSafeArea()
                controls
            case .notDetermined:
                ProgressView().tint(.white)
            case .denied:
                deniedState
            }
        }
        .onAppear {
            controller.onAppear()
            location.requestPermission()
            location.start()
        }
        .onDisappear { controller.onDisappear() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIDevice.orientationDidChangeNotification)) { _ in
            let o = UIDevice.current.orientation
            if o.isValidInterfaceOrientation { orientation = o }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack {
            HStack {
                gpsIndicator
                Spacer()
                flashButton
            }
            .padding(.horizontal)

            Spacer()
            if controller.availableLenses.count > 1 { lensSelector }
            bottomBar
        }
        .padding(.vertical)
    }

    private var gpsIndicator: some View {
        let level = location.snapshot?.accuracyLevel
        return Label {
            Text(gpsText).font(.caption.monospacedDigit())
        } icon: {
            Image(systemName: "location.fill")
        }
        .foregroundStyle(color(for: level))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.4), in: Capsule())
        .rotationEffect(rotation)
    }

    private var gpsText: String {
        guard let s = location.snapshot else { return "GPS --" }
        return "GPS \(Int(s.accuracyMeters.rounded()))m"
    }

    private var flashButton: some View {
        Button { controller.toggleFlash() } label: {
            Image(systemName: controller.flashOn ? "bolt.fill" : "bolt.slash.fill")
                .rotationEffect(rotation)
        }
        .glyphStyle()
    }

    private var lensSelector: some View {
        HStack(spacing: 8) {
            ForEach(controller.availableLenses, id: \.self) { lens in
                Button { controller.selectLens(lens) } label: {
                    Text(label(for: lens))
                        .font(.caption.bold())
                        .foregroundStyle(controller.lens == lens ? .yellow : .white)
                        .frame(width: 40, height: 40)
                        .background(.black.opacity(0.4), in: Circle())
                        .rotationEffect(rotation)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        HStack {
            // Mode switch — video disabled this increment.
            Text("PHOTO").font(.caption.bold()).foregroundStyle(.yellow)
                .rotationEffect(rotation)
                .frame(width: 60)

            Spacer()
            shutterButton
            Spacer()

            Button { controller.toggleFacing() } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .rotationEffect(rotation)
            }
            .glyphStyle()
            .frame(width: 60)
        }
        .padding(.horizontal, 24)
    }

    private var shutterButton: some View {
        Button { controller.shutter() } label: {
            Circle().fill(.white).frame(width: 70, height: 70)
                .overlay(Circle().stroke(.white, lineWidth: 4).padding(4))
                .opacity(controller.isCapturing ? 0.5 : 1)
        }
        .disabled(controller.isCapturing)
    }

    private var deniedState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill").font(.largeTitle)
            Text("Camera access is off.")
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: - Orientation

    private var rotation: Angle {
        switch orientation {
        case .landscapeLeft:      return .degrees(90)
        case .landscapeRight:     return .degrees(-90)
        case .portraitUpsideDown: return .degrees(180)
        default:                  return .degrees(0)
        }
    }

    private func color(for level: AccuracyLevel?) -> Color {
        switch level {
        case .good:   return .green
        case .normal: return .yellow
        case .bad:    return .red
        case nil:     return .gray
        }
    }

    private func label(for lens: Lens) -> String {
        switch lens {
        case .ultraWide: return ".5"
        case .wide:      return "1x"
        case .tele:      return "2x"
        }
    }
}

private extension View {
    /// Shared look for the round white control glyphs.
    func glyphStyle() -> some View {
        font(.title3)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.black.opacity(0.4), in: Circle())
    }
}

#Preview {
    let location = LocationProvider()
    return CameraView(controller: CameraController(location: location),
                      location: location)
}
