import Foundation

/// Formats `LocationSnapshot` fields into overlay item strings. Pure and
/// side-effect free so it can be unit tested. Formats (coord style, unit)
/// belong here, not in location (location.md "Non-interests").
nonisolated enum OverlayFormatter {
    static func coordinates(_ c: Coordinate, format: OverlaySettings.CoordFormat) -> String {
        switch format {
        case .latLon:
            return String(format: "%.6f, %.6f", c.latitude, c.longitude)
        case .dms:
            return "\(dms(c.latitude, positive: "N", negative: "S")) "
                 + "\(dms(c.longitude, positive: "E", negative: "W"))"
        }
    }

    static func altitude(_ meters: Double, unit: OverlaySettings.Unit) -> String {
        switch unit {
        case .metric:   return String(format: "%.0f m", meters)
        case .imperial: return String(format: "%.0f ft", meters * 3.28084)
        }
    }

    static func accuracy(_ meters: Double, unit: OverlaySettings.Unit) -> String {
        switch unit {
        case .metric:   return String(format: "\u{00B1}%.0f m", meters)
        case .imperial: return String(format: "\u{00B1}%.0f ft", meters * 3.28084)
        }
    }

    static func heading(_ h: Heading) -> String {
        String(format: "%.0f\u{00B0} %@", h.degrees, h.cardinal.rawValue)
    }

    /// Locale-default date + time (e.g. en_US "6/30/2026, 2:35:18 PM",
    /// de_DE "30.06.2026, 14:35:18").
    /// TODO: decide the default format per locale; user customization via
    /// overlay.style.dateFormat (pro) once the settings framework lands.
    static func time(_ date: Date, locale: Locale = .current,
                     timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = DateFormatter.dateFormat(
            fromTemplate: "yMdHms", options: 0, locale: locale)
        return formatter.string(from: date)
    }

    private static func dms(_ degrees: Double, positive: String, negative: String) -> String {
        let hemisphere = degrees < 0 ? negative : positive
        let total = abs(degrees)
        let d = Int(total)
        let m = Int((total - Double(d)) * 60)
        let s = (total - Double(d) - Double(m) / 60) * 3600
        return String(format: "%d\u{00B0}%02d'%04.1f\"%@", d, m, s, hemisphere)
    }
}
