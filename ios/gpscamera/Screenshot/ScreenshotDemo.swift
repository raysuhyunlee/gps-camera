//
//  ScreenshotDemo.swift
//  Screenshot demo mode (screenshots.md): a DEBUG-only launch-arg switch that
//  makes the simulator render an authentic Main screen for App Store shots -
//  a pre-arranged scene photo behind the (black-in-simulator) camera feed, a
//  curated location snapshot, a forced entitlement, and a seeded gallery.
//
//  Consumers read `ScreenshotDemo.current` directly, so production initializer
//  signatures stay untouched. The whole file compiles out of Release.
//

#if DEBUG
import UIKit

struct ScreenshotDemo {
    /// Active when launched with `-ScreenshotDemo 1` (UITest or `simctl --args`).
    let isActive: Bool
    /// Scene id from `-Scene <id>`; loads `screenshot-scene-<id>.jpg` from the bundle.
    let scene: String?
    /// `-ScreenshotPro 1` (default) forces `.pro` for clean shots; `0` keeps
    /// `.free` so the paywall + banner render for their own screenshots.
    let forcePro: Bool

    static let current = ScreenshotDemo()

    private init() {
        let args = ProcessInfo.processInfo.arguments
        func flag(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        isActive = flag("-ScreenshotDemo") == "1"
        scene = flag("-Scene")
        forcePro = flag("-ScreenshotPro") != "0"
    }

    /// The scene photo drawn behind the camera feed; nil falls back to the real
    /// preview (black in the simulator). Bundled as `screenshot-scene-<id>.jpg`
    /// under `Screenshot/Assets/scenes/`.
    var sceneImage: UIImage? {
        guard isActive, let scene,
              let url = Bundle.main.url(forResource: "screenshot-scene-\(scene)",
                                        withExtension: "jpg")
        else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Curated location for the overlay card + GPS indicator, matched per scene
    /// so the address/coordinates read sensibly. Falls back to a default.
    var snapshot: LocationSnapshot {
        Self.scenes[scene ?? ""] ?? Self.defaultSnapshot
    }

    /// The app-language code (L10n) for this run, derived from the standard
    /// `-AppleLanguages` fastlane snapshot injects. nil = leave the app default.
    var locale: String? {
        guard isActive, let pref = Locale.preferredLanguages.first else { return nil }
        let codes = L10n.languages.map(\.code)
        if codes.contains(pref) { return pref }                 // exact
        if let scripted = codes.first(where: { pref.hasPrefix($0) }) {
            return scripted                                     // zh-Hans-CN -> zh-Hans
        }
        let base = pref.split(separator: "-").first.map(String.init) ?? pref
        return codes.first { $0 == base || $0.hasPrefix(base + "-") }
    }

    // MARK: - Curated scenes

    // Add one entry per photo you drop in `Screenshot/Assets/scenes/`, matching
    // the address/coordinate to the scene. Accuracy < 10 m tints the GPS icon
    // green (AccuracyLevel.good). Example:
    //   "mountain": LocationSnapshot(
    //       coordinate: Coordinate(latitude: 46.5597, longitude: 8.5610),
    //       altitude: 2106, accuracyMeters: 4.2, heading: Heading(degrees: 312),
    //       timestamp: .now, address: "Furkapass, Realp, Uri, Switzerland",
    //       weather: nil)
    private static let scenes: [String: LocationSnapshot] = [
        // Night skyline shot from Top of the Rock, facing south at the
        // Empire State Building (`screenshot-scene-new-york.jpg`).
        "new-york": LocationSnapshot(
            coordinate: Coordinate(latitude: 40.7593, longitude: -73.9793),
            altitude: 259, accuracyMeters: 4.8, heading: Heading(degrees: 180),
            timestamp: .now, address: "30 Rockefeller Plaza, New York, NY 10112",
            weather: nil),
    ]

    private static let defaultSnapshot = LocationSnapshot(
        coordinate: Coordinate(latitude: 37.5326, longitude: 127.0246),
        altitude: 38.2, accuracyMeters: 4.5,
        heading: Heading(degrees: 275), timestamp: .now,
        address: "12 Hannam-daero, Yongsan-gu, Seoul", weather: nil)
}
#endif
