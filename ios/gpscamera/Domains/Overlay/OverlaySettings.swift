import SwiftUI

nonisolated enum OverlaySettingKey {
    static let enabled = "overlay.enabled"
    static let layout = "overlay.layout"   // OverlayAnchor raw value
    static let itemCoordinates = "overlay.item.coordinates"
    static let itemAltitude = "overlay.item.altitude"
    static let itemAccuracy = "overlay.item.accuracy"
    static let itemCompass = "overlay.item.compass"
    static let itemTime = "overlay.item.time"
    static let itemAddress = "overlay.item.address"
    static let itemWatermark = "overlay.item.watermark"
    static let styleFont = "overlay.style.font"
    static let styleSize = "overlay.style.size"
    static let styleTextColor = "overlay.style.textColor"
    static let styleBgColor = "overlay.style.bgColor"
    static let styleBgOpacity = "overlay.style.bgOpacity"
    static let styleCoordFormat = "overlay.style.coordFormat"
    static let styleUnit = "overlay.style.unit"
}

/// Typed overlay settings (overlay.md "Settings"). Deferred items (map, QR,
/// note, weather, logo) land with their features.
struct OverlaySettings {
    var enabled = true
    var anchor = OverlayAnchor.bottomLeading

    var showCoordinates = true
    var showAltitude = true
    var showAccuracy = true
    var showHeading = true
    var showTime = true
    var showAddress = true
    var showWatermark = true   // pro to disable

    var style = Style()

    /// overlay.style.* — all pro; defaults apply for free users.
    struct Style {
        var font = FontChoice.design(.system) // overlay.style.font
        var fontSize: CGFloat = 12            // overlay.style.size
        var textColor = Color.white           // overlay.style.textColor
        var bgColor = Color.black             // overlay.style.bgColor
        var bgOpacity = 0.4                   // overlay.style.bgOpacity
        var coordFormat = CoordFormat.latLon
        var unit = Unit.metric

        /// The overlay text font at `size` (watermark passes a smaller one).
        func textFont(_ size: CGFloat) -> Font {
            switch font {
            case .design(let design):
                return .system(size: size, weight: .medium, design: design.design)
                    .monospacedDigit()
            case .family(let family):
                // Bundled font (BundledFonts); SwiftUI falls back to the
                // system face if the family is missing.
                return .custom(family, size: size)
            }
        }
    }

    /// overlay.style.font value: a system design or a bundled family name.
    enum FontChoice: Equatable {
        case design(FontDesign)
        case family(String)

        init(rawValue: String) {
            if let design = FontDesign(rawValue: rawValue) {
                self = .design(design)
            } else if rawValue.isEmpty {
                self = .design(.system)
            } else {
                self = .family(rawValue)
            }
        }
    }

    enum FontDesign: String {
        case system, serif, rounded, mono
        var design: Font.Design {
            switch self {
            case .system: return .default
            case .serif: return .serif
            case .rounded: return .rounded
            case .mono: return .monospaced
            }
        }
    }
    enum CoordFormat: String { case latLon = "lat-lon", dms }   // overlay.style.coordFormat
    enum Unit: String { case metric, imperial }                 // overlay.style.unit

    init() {}

    init(from store: SettingsStore) {
        enabled = store.bool(OverlaySettingKey.enabled)
        anchor = OverlayAnchor(rawValue: store.string(OverlaySettingKey.layout))
            ?? .bottomLeading
        showCoordinates = store.bool(OverlaySettingKey.itemCoordinates)
        showAltitude = store.bool(OverlaySettingKey.itemAltitude)
        showAccuracy = store.bool(OverlaySettingKey.itemAccuracy)
        showHeading = store.bool(OverlaySettingKey.itemCompass)
        showTime = store.bool(OverlaySettingKey.itemTime)
        showAddress = store.bool(OverlaySettingKey.itemAddress)
        showWatermark = store.bool(OverlaySettingKey.itemWatermark)
        style.font = FontChoice(rawValue: store.string(OverlaySettingKey.styleFont))
        style.fontSize = CGFloat(store.number(OverlaySettingKey.styleSize))
        style.textColor = Color(settingHex: store.string(OverlaySettingKey.styleTextColor))
        style.bgColor = Color(settingHex: store.string(OverlaySettingKey.styleBgColor))
        style.bgOpacity = store.number(OverlaySettingKey.styleBgOpacity)
        style.coordFormat = CoordFormat(rawValue: store.string(OverlaySettingKey.styleCoordFormat))
            ?? .latLon
        style.unit = Unit(rawValue: store.string(OverlaySettingKey.styleUnit)) ?? .metric
    }
}

/// The bundled OFL font families (Resources/Fonts, registered by
/// BundledFonts). Values double as `Font.custom` family names.
nonisolated enum OverlayFontCatalog {
    static let families = [
        "Inter", "Open Sans", "Lato", "Montserrat", "Poppins", "Nunito",
        "Raleway", "Quicksand", "Comfortaa", "Oswald", "Bebas Neue",
        "Archivo Narrow", "Merriweather", "Playfair Display", "Lora",
        "Caveat", "Pacifico", "Dancing Script", "Shadows Into Light",
        "JetBrains Mono",
    ]
}

/// Overlay sections (overlay.md "Settings"; placement from overview.md).
/// `overlay.enabled` is the master switch: every other row greys out while it
/// is off. Item toggles live in the "Display items" sub-section.
/// Preview + position-editor `custom` controls: deferred with the editor widget.
nonisolated struct OverlaySettingsProvider: SettingsProviding {
    private static let master: (SettingsStore) -> Bool = {
        $0.bool(OverlaySettingKey.enabled)
    }

    /// Each choice previews in its own typeface.
    private static var fontOptions: [SelectOption] {
        let designs: [(OverlaySettings.FontDesign, L10nKey)] = [
            (.system, "System"), (.serif, "Serif"),
            (.rounded, "Rounded"), (.mono, "Monospaced"),
        ]
        return designs.map { design, title in
            SelectOption(value: design.rawValue, titleKey: title,
                         previewFont: .system(size: 17, design: design.design))
        } + OverlayFontCatalog.families.map {
            SelectOption(value: $0, titleKey: $0, previewFont: .custom($0, size: 17))
        }
    }

    var settingsSections: [SettingsSection] {
        let items: [(String, L10nKey)] = [
            (OverlaySettingKey.itemCoordinates, "Coordinates"),
            (OverlaySettingKey.itemAltitude, "Altitude"),
            (OverlaySettingKey.itemAccuracy, "Accuracy"),
            (OverlaySettingKey.itemCompass, "Compass"),
            (OverlaySettingKey.itemTime, "Time"),
            (OverlaySettingKey.itemAddress, "Address"),
        ]
        return [SettingsSection(id: "overlay", titleKey: "Overlay", items: [
            SettingItem(key: OverlaySettingKey.enabled,
                        titleKey: "Include overlay in photo/video",
                        control: .toggle, defaultValue: .bool(true)),
            SettingItem(key: "overlay.nav.items", titleKey: "Display items",
                        control: .navigation(sectionRef: "overlay.items"),
                        enabledWhen: Self.master),
            SettingItem(key: OverlaySettingKey.styleFont, titleKey: "Font",
                        control: .select(Self.fontOptions),
                        defaultValue: .string("system"), gate: .pro,
                        enabledWhen: Self.master),
            SettingItem(key: OverlaySettingKey.styleSize, titleKey: "Font size",
                        control: .stepper(range: 10...20, step: 1),
                        defaultValue: .number(12), gate: .pro,
                        enabledWhen: Self.master),
            SettingItem(key: OverlaySettingKey.styleTextColor, titleKey: "Text color",
                        control: .color, defaultValue: .string("#FFFFFFFF"), gate: .pro,
                        enabledWhen: Self.master),
            SettingItem(key: OverlaySettingKey.styleBgColor, titleKey: "Background color",
                        control: .color, defaultValue: .string("#000000FF"), gate: .pro,
                        enabledWhen: Self.master),
            SettingItem(key: OverlaySettingKey.styleBgOpacity, titleKey: "Background opacity",
                        control: .slider(range: 0...1),
                        defaultValue: .number(0.4), gate: .pro,
                        enabledWhen: Self.master),
            SettingItem(key: OverlaySettingKey.styleCoordFormat, titleKey: "Coordinate format",
                        control: .select([SelectOption(value: "lat-lon", titleKey: "Lat, Lon"),
                                          SelectOption(value: "dms", titleKey: "DMS")]),
                        defaultValue: .string("lat-lon"), gate: .pro,
                        enabledWhen: Self.master),
            SettingItem(key: OverlaySettingKey.styleUnit, titleKey: "Unit",
                        control: .select([SelectOption(value: "metric", titleKey: "Metric"),
                                          SelectOption(value: "imperial", titleKey: "Imperial")]),
                        defaultValue: .string("metric"), gate: .pro,
                        enabledWhen: Self.master),
            // overlay.layout persists the drag-positioned anchor (Main screen).
            // Hidden until the position-editor widget lands; registered so the
            // store knows its default.
            SettingItem(key: OverlaySettingKey.layout, titleKey: "Adjust position",
                        control: .custom(controlRef: "overlay.layout"),
                        defaultValue: .string(OverlayAnchor.bottomLeading.rawValue),
                        visibleWhen: { _ in false }),
        ]),
        SettingsSection(id: "overlay.items", titleKey: "Display items", items:
            items.map { key, title in
                SettingItem(key: key, titleKey: title,
                            control: .toggle, defaultValue: .bool(true),
                            enabledWhen: Self.master)
            } + [
                SettingItem(key: OverlaySettingKey.itemWatermark, titleKey: "Watermark",
                            control: .toggle, defaultValue: .bool(true), gate: .pro,
                            enabledWhen: Self.master),
            ])]
    }
}
