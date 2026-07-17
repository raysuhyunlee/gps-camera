#if DEBUG
import SwiftUI

/// Presents the requested real screen at launch so host-side simulator capture
/// does not depend on XCTest accessibility snapshots or navigation timing.
struct ScreenshotPoseHost<Main: View>: View {
    let screen: ScreenshotDemo.Screen
    let main: Main
    let settings: () -> AnyView
    let gallery: () -> AnyView

    @State private var showSettings = false
    @State private var showGallery = false

    var body: some View {
        main
            .sheet(isPresented: $showSettings) { settings() }
            .fullScreenCover(isPresented: $showGallery) { gallery() }
            .environment(\.layoutDirection,
                         ScreenshotDemo.current.isRightToLeft ? .rightToLeft : .leftToRight)
            .task {
                showSettings = screen == .settings
                showGallery = screen == .gallery
            }
    }
}
#endif
