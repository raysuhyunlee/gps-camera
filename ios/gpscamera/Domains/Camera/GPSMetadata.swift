import Foundation
import ImageIO

/// Builds the `kCGImagePropertyGPSDictionary` payload from a `LocationSnapshot`,
/// for merging into a captured photo's EXIF. Pure and side-effect free so it can
/// be unit tested.
nonisolated enum GPSMetadata {
    static func dictionary(from snapshot: LocationSnapshot) -> [String: Any] {
        var gps: [String: Any] = [:]
        let lat = snapshot.coordinate.latitude
        let lon = snapshot.coordinate.longitude

        gps[kCGImagePropertyGPSLatitude as String] = abs(lat)
        gps[kCGImagePropertyGPSLatitudeRef as String] = lat >= 0 ? "N" : "S"
        gps[kCGImagePropertyGPSLongitude as String] = abs(lon)
        gps[kCGImagePropertyGPSLongitudeRef as String] = lon >= 0 ? "E" : "W"

        gps[kCGImagePropertyGPSAltitude as String] = abs(snapshot.altitude)
        gps[kCGImagePropertyGPSAltitudeRef as String] = snapshot.altitude >= 0 ? 0 : 1

        gps[kCGImagePropertyGPSHPositioningError as String] = snapshot.accuracyMeters

        if let heading = snapshot.heading {
            gps[kCGImagePropertyGPSImgDirection as String] = heading.degrees
            gps[kCGImagePropertyGPSImgDirectionRef as String] = "T" // true north
        }

        let utc = TimeZone(identifier: "UTC")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                   from: snapshot.timestamp)
        if let y = c.year, let mo = c.month, let d = c.day {
            gps[kCGImagePropertyGPSDateStamp as String] =
                String(format: "%04d:%02d:%02d", y, mo, d)
        }
        if let h = c.hour, let mi = c.minute, let s = c.second {
            gps[kCGImagePropertyGPSTimeStamp as String] =
                String(format: "%02d:%02d:%02d", h, mi, s)
        }
        return gps
    }
}
