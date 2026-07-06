import SwiftUI

/// The Main screen: live camera preview with the top/bottom control sections
/// (camera.md "Layout"). Hosts the live overlay layer and the pro banner.
struct CameraView: View {
    @ObservedObject var controller: CameraController
    @ObservedObject var location: LocationProvider
    let overlay: OverlayRendering
    /// Gallery seam; the recent-capture thumbnail control (opens the gallery).
    let gallery: GalleryProviding
    let settings: SettingsStore
    let registry: SettingsRegistry
    /// Monetization seams; gate pro settings rows, route locked rows to the
    /// paywall, host the thin pro banner under the top controls.
    let entitlement: EntitlementProviding
    let paywall: PaywallProviding
    let banner: ProBannerProviding

    @State private var recordStart: Date?
    @State private var showGPSTooltip = false
    @State private var showSettings = false
    @State private var settingsHighlight: String?
    @State private var mismatchKey: String?
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch controller.authorization {
            case .authorized:
                CameraPreview(session: controller.previewSession,
                              freezeFrame: controller.freezeFrame)
                    .ignoresSafeArea()
                controls
                if controller.isRecording { recordingIndicator }
            case .notDetermined:
                ProgressView().tint(.white)
            case .denied:
                deniedState
            }
        }
        .onAppear {
            // Interface is locked to portrait, so sections + fixed controls keep
            // their positions; we track device orientation ourselves to rotate
            // the rotatable controls in place (camera.md "Device Orientation").
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            controller.onAppear()
            location.requestPermission()
            location.start()
        }
        .onDisappear {
            controller.onDisappear()
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .onChange(of: controller.isRecording) { _, recording in
            recordStart = recording ? Date() : nil
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIDevice.orientationDidChangeNotification)) { _ in
            controller.deviceOrientationChanged(UIDevice.current.orientation)
        }
        .sheet(isPresented: $showSettings, onDismiss: { settingsHighlight = nil }) {
            SettingsScreen(registry: registry, store: settings,
                           entitled: { entitlement.entitlement == .pro },
                           onProLock: { _ in showPaywall = true },
                           highlightKey: settingsHighlight,
                           debugScreen: { AnyView(ContentView(pro: entitlement as? ProStore)) })
                .sheet(isPresented: $showPaywall) { paywall.paywallScreen() }
        }
        // Permission-coupled mismatch popup (foundation.md): non-blocking, the
        // capture already proceeded with the feature skipped.
        .onReceive(NotificationCenter.default.publisher(
            for: .settingPermissionMismatch)) { note in
            mismatchKey = note.userInfo?["key"] as? String
        }
        .alert("Permission is off", isPresented: .init(
            get: { mismatchKey != nil }, set: { if !$0 { mismatchKey = nil } })) {
            Button("Close", role: .cancel) {}
            Button("Go to Settings") {
                settingsHighlight = mismatchKey
                showSettings = true
            }
        } message: {
            Text("A setting that needs a permission stayed on, but the permission was revoked. The capture continued without it.")
        }
    }

    // MARK: - Layout

    private var controls: some View {
        VStack(spacing: 0) {
            topSection
            // Pro banner - hosted, not owned (monetization domain): a thin
            // one-line strip that opens the paywall itself; hidden for pro.
            banner.mainBanner()
                .disabled(controller.isRecording)
            // Live overlay layer - hosted, not owned (overlay domain): the
            // overlay anchors + drags itself within the area between the
            // control sections, following the capture orientation. The ZStack
            // keeps this flexible region expanded even when the overlay is
            // off (liveLayer returns EmptyView, which vanishes from layout).
            ZStack {
                overlay.liveLayer(snapshot: location.snapshot,
                                  orientation: controller.captureOrientation)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if controller.availableLenses.count > 1 {
                lensSelector.padding(.bottom, 12)   // floats over the preview
            }
            bottomSection
        }
    }

    private var topSection: some View {
        HStack {
            gpsStatus
            Spacer()
            otherControls
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.4), ignoresSafeAreaEdges: .top)
    }

    private var bottomSection: some View {
        VStack(spacing: 14) {
            HStack {
                galleryButton
                Spacer()
                shutterButton
                Spacer()
                facingButton
            }
            modeSwitch
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.4), ignoresSafeAreaEdges: .bottom)
    }

    // MARK: - Rotatable controls (square, rotate with orientation)

    private var gpsStatus: some View {
        let level = location.snapshot?.accuracyLevel
        return Button { showGPSTooltip.toggle() } label: {
            Image(systemName: "location.fill")
                .foregroundStyle(color(for: level))
                .frame(width: 44, height: 44)
        }
        .rotatable(rotation)
        .popover(isPresented: $showGPSTooltip) {
            Text(gpsStatusText(level))
                .font(.caption)
                .padding(8)
                .presentationCompactAdaptation(.popover)
        }
    }

    /// Top-right group. Hypothetically grouped, but each rotates individually.
    private var otherControls: some View {
        HStack(spacing: 8) {
            flashButton
            settingsButton
        }
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape.fill")
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .rotatable(rotation)
    }

    private var flashButton: some View {
        Button { controller.toggleFlash() } label: {
            Image(systemName: controller.flashOn ? "bolt.fill" : "bolt.slash.fill")
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .rotatable(rotation)
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
                }
                .rotatable(rotation)
                .disabled(controller.isRecording)
            }
        }
    }

    /// Recent-capture thumbnail - hosted, not owned (gallery domain).
    private var galleryButton: some View {
        gallery.thumbnailButton()
            .rotatable(rotation)
            .disabled(controller.isRecording)
    }

    private var facingButton: some View {
        Button { controller.toggleFacing() } label: {
            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .rotatable(rotation)
        .disabled(controller.isRecording)
    }

    // MARK: - Anchored controls (world-space anchor: relocate + rotate)

    /// Anchored to the world-space top-middle: relocates to the edge matching
    /// the device orientation and rotates upright. Freezes while recording and
    /// on orientation lock, like rotatable controls.
    private var recordingIndicator: some View {
        let orientation = controller.captureOrientation
        return Label {
            if let recordStart {
                Text(timerInterval: recordStart...Date.distantFuture, countsDown: false)
                    .font(.caption.monospacedDigit())
            }
        } icon: {
            Circle().fill(.red).frame(width: 8, height: 8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.4), in: Capsule())
        .rotationEffect(CameraOrientation.controlAngle(for: orientation))
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: CameraOrientation.anchorAlignment(for: orientation))
        .padding(8)
        .animation(.easeInOut(duration: 0.25), value: orientation)
    }

    // MARK: - Fixed controls (never rotate)

    private var shutterButton: some View {
        Button { controller.shutter() } label: {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 70, height: 70)
                if controller.mode == .video {
                    RoundedRectangle(cornerRadius: controller.isRecording ? 6 : 29)
                        .fill(.red)
                        .frame(width: controller.isRecording ? 32 : 58,
                               height: controller.isRecording ? 32 : 58)
                } else {
                    Circle().fill(.white).frame(width: 58, height: 58)
                        .opacity(controller.isCapturing ? 0.5 : 1)
                }
            }
        }
        .disabled(controller.isCapturing)
        .animation(.easeInOut(duration: 0.2), value: controller.isRecording)
    }

    /// Liquid Glass segmented control (iOS 26 default for `.segmented`).
    private var modeSwitch: some View {
        Picker("Mode", selection: Binding(
            get: { controller.mode },
            set: { controller.setMode($0) }
        )) {
            ForEach([CameraMode.photo, .video], id: \.self) { mode in
                Text(label(for: mode)).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
        .background(.gray.opacity(0.4), in: Capsule())   // keeps it legible over bright previews
        .disabled(controller.isRecording)
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

    // MARK: - Helpers

    private var rotation: Angle {
        CameraOrientation.controlAngle(for: controller.captureOrientation)
    }

    private func color(for level: AccuracyLevel?) -> Color {
        switch level {
        case .good:   return .green
        case .normal: return .yellow
        case .bad:    return .red
        case nil:     return .gray
        }
    }

    private func gpsStatusText(_ level: AccuracyLevel?) -> String {
        switch level {
        case .good:   return "Good"
        case .normal: return "Normal"
        case .bad:    return "Bad"
        case nil:     return "No signal"
        }
    }

    private func label(for lens: Lens) -> String {
        switch lens {
        case .ultraWide: return ".5"
        case .wide:      return "1x"
        case .tele:      return "2x"
        }
    }

    private func label(for mode: CameraMode) -> String {
        switch mode {
        case .photo: return "PHOTO"
        case .video: return "VIDEO"
        }
    }
}

private extension View {
    /// Rotatable control: rotates in place to match device orientation, animated.
    func rotatable(_ angle: Angle) -> some View {
        rotationEffect(angle).animation(.easeInOut(duration: 0.25), value: angle)
    }
}

#Preview {
    let store = SettingsStore()
    let registry = SettingsRegistry(
        providers: [CameraSettingsProvider(), OverlaySettingsProvider(),
                    FilenameSettingsProvider()],
        order: ["camera.capture": 20, "overlay": 30, "filename": 40],
        store: store)
    let location = LocationProvider()
    let overlay = OverlayRenderer(store: store)
    let pro = ProStore()
    return CameraView(controller: CameraController(location: location, overlay: overlay,
                                                   filename: DefaultFilenameProvider(store: store),
                                                   store: store,
                                                   events: NoopTracker(),
                                                   metrics: UsageMetrics()),
                      location: location, overlay: overlay,
                      gallery: Gallery(store: CaptureStore(), events: NoopTracker()),
                      settings: store, registry: registry,
                      entitlement: FixedEntitlement(), paywall: pro, banner: pro)
}
