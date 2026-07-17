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
    enum Screen: String {
        case main
        case settings
        case gallery
    }

    /// Active when launched with `-ScreenshotDemo 1` (UITest or `simctl --args`).
    let isActive: Bool
    /// Scene id from `-Scene <id>`; loads `screenshot-scene-<id>.jpg` from the bundle.
    let scene: String?
    /// `-ScreenshotPro 1` (default) forces `.pro` for clean shots; `0` keeps
    /// `.free` so the paywall + banner render for their own screenshots.
    let forcePro: Bool
    /// Store locale requested by the direct-capture pipeline. This avoids
    /// simulator foreground failures while rapidly switching writing systems.
    let requestedLocale: String?
    /// Direct-capture pose. This bypasses flaky UI-test navigation while still
    /// rendering the real product screens.
    let screen: Screen

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
        requestedLocale = flag("-ScreenshotLocale")
        screen = Screen(rawValue: flag("-ScreenshotScreen") ?? "main") ?? .main
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
    /// so the address/coordinates read sensibly. The overlay renders in the run's
    /// locale, so the address is localized too: non-Latin stores get a native
    /// spelling from `localizedAddresses`; Latin-script stores keep the scene's
    /// default (proper nouns are not translated). nil for an unknown scene.
    var snapshot: LocationSnapshot? {
        guard let scene, let base = Self.scenes[scene] else { return nil }
        guard let locale, let address = Self.localizedAddresses[scene]?[locale]
        else { return base }
        return LocationSnapshot(
            coordinate: base.coordinate, altitude: base.altitude,
            accuracyMeters: base.accuracyMeters, heading: base.heading,
            timestamp: base.timestamp, address: address, weather: base.weather)
    }

    /// The app-language code (L10n) for this run, derived from the standard
    /// `-AppleLanguages` fastlane snapshot injects. nil = leave the app default.
    var locale: String? {
        guard isActive,
              let pref = requestedLocale ?? Locale.preferredLanguages.first
        else { return nil }
        let codes = L10n.languages.map(\.code)
        if codes.contains(pref) { return pref }                 // exact
        if let scripted = codes.first(where: { pref.hasPrefix($0) }) {
            return scripted                                     // zh-Hans-CN -> zh-Hans
        }
        var base = pref.split(separator: "-").first.map(String.init) ?? pref
        base = Self.localeAliases[base] ?? base                 // store "no" -> L10n "nb"
        return codes.first { $0 == base || $0.hasPrefix(base + "-") }
    }

    var isRightToLeft: Bool {
        guard let locale else { return false }
        return locale == "ar" || locale == "he"
    }

    /// App Store storefront codes whose base differs from the L10n code.
    private static let localeAliases = ["no": "nb"]

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

    // Native address spelling per non-Latin store (Apple-Maps style). Latin-script
    // stores fall back to the scene's default address above. Machine-drafted;
    // review with native speakers. Keyed by scene, then L10n code.
    private static let localizedAddresses: [String: [String: String]] = [
        "new-york": [
            "ko":      "\u{BBF8}\u{AD6D} \u{B274}\u{C695} \u{B85D}\u{D3A0}\u{B7EC} \u{D50C}\u{B77C}\u{C790} 30",
            "ja":      "\u{30A2}\u{30E1}\u{30EA}\u{30AB} \u{30CB}\u{30E5}\u{30FC}\u{30E8}\u{30FC}\u{30AF} \u{30ED}\u{30C3}\u{30AF}\u{30D5}\u{30A7}\u{30E9}\u{30FC}\u{30FB}\u{30D7}\u{30E9}\u{30B6}30",
            "zh-Hans": "\u{7F8E}\u{56FD}\u{7EBD}\u{7EA6}\u{6D1B}\u{514B}\u{83F2}\u{52D2}\u{5E7F}\u{573A}30\u{53F7}",
            "zh-Hant": "\u{7F8E}\u{570B}\u{7D10}\u{7D04}\u{6D1B}\u{514B}\u{6590}\u{52D2}\u{5EE3}\u{5834}30\u{865F}",
            "ru":      "\u{0420}\u{043E}\u{043A}\u{0444}\u{0435}\u{043B}\u{043B}\u{0435}\u{0440}-\u{041F}\u{043B}\u{0430}\u{0437}\u{0430}, 30, \u{041D}\u{044C}\u{044E}-\u{0419}\u{043E}\u{0440}\u{043A}",
            "uk":      "\u{0420}\u{043E}\u{043A}\u{0444}\u{0435}\u{043B}\u{043B}\u{0435}\u{0440}-\u{041F}\u{043B}\u{0430}\u{0437}\u{0430}, 30, \u{041D}\u{044C}\u{044E}-\u{0419}\u{043E}\u{0440}\u{043A}",
            "el":      "\u{03A1}\u{03CC}\u{03BA}\u{03C6}\u{03B5}\u{03BB}\u{03B5}\u{03C1} \u{03A0}\u{03BB}\u{03AC}\u{03B6}\u{03B1} 30, \u{039D}\u{03AD}\u{03B1} \u{03A5}\u{03CC}\u{03C1}\u{03BA}\u{03B7}",
            "th":      "\u{0E23}\u{0E47}\u{0E2D}\u{0E01}\u{0E40}\u{0E01}\u{0E2D}\u{0E40}\u{0E1F}\u{0E25}\u{0E40}\u{0E25}\u{0E2D}\u{0E23}\u{0E4C}\u{0E1E}\u{0E25}\u{0E32}\u{0E0B}\u{0E32} 30, \u{0E19}\u{0E34}\u{0E27}\u{0E22}\u{0E2D}\u{0E23}\u{0E4C}\u{0E01}",
            "hi":      "30 \u{0930}\u{0949}\u{0915}\u{0947}\u{092B}\u{0947}\u{0932}\u{0930} \u{092A}\u{094D}\u{0932}\u{093E}\u{095B}\u{093E}, \u{0928}\u{094D}\u{092F}\u{0942}\u{092F}\u{0949}\u{0930}\u{094D}\u{0915}",
            "ar":      "30 \u{0631}\u{0648}\u{0643}\u{0641}\u{0644}\u{0631} \u{0628}\u{0644}\u{0627}\u{0632}\u{0627}\u{060C} \u{0646}\u{064A}\u{0648}\u{064A}\u{0648}\u{0631}\u{0643}",
            "he":      "\u{05E8}\u{05D5}\u{05E7}\u{05E4}\u{05DC}\u{05E8} \u{05E4}\u{05DC}\u{05D0}\u{05D6}\u{05D4} 30, \u{05E0}\u{05D9}\u{05D5} \u{05D9}\u{05D5}\u{05E8}\u{05E7}",
        ],
    ]
}
#endif
