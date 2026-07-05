import SwiftUI

/// Overlay settings, hardcoded to spec defaults until the settings framework
/// lands (overlay.md "Settings"). TODO: read from SettingsStore.
struct OverlaySettings {
    var enabled = true                    // overlay.enabled
    var anchor = OverlayAnchor.bottomLeading   // overlay.layout

    // overlay.item.* — one toggle per item. Deferred items (map, QR, note,
    // weather, logo) land with their features.
    var showCoordinates = true
    var showAltitude = true
    var showAccuracy = true
    var showHeading = true
    var showTime = true
    var showAddress = true
    var showWatermark = true              // overlay.item.watermark (pro to disable)

    var style = Style()

    /// overlay.style.* — all pro; defaults apply for free users.
    struct Style {
        var fontSize: CGFloat = 13        // overlay.style.size
        var textColor = Color.white       // overlay.style.textColor
        var bgColor = Color.black         // overlay.style.bgColor
        var bgOpacity = 0.4               // overlay.style.bgOpacity
        var coordFormat = CoordFormat.latLon
        var unit = Unit.metric
    }

    enum CoordFormat { case latLon, dms } // overlay.style.coordFormat
    enum Unit { case metric, imperial }   // overlay.style.unit
}
