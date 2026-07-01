import Foundation

struct LocationSnapshot: Equatable {
    let coordinate: Coordinate
    let altitude: Double          // meters
    let accuracyMeters: Double    // horizontal accuracy radius, meters
    let heading: Heading?
    let timestamp: Date
    let address: String?          // reverse-geocoded, nil until resolved
    let weather: Weather?         // TODO

    var accuracyLevel: AccuracyLevel { AccuracyLevel(accuracyMeters: accuracyMeters) }
}

struct Coordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

enum AccuracyLevel {
    case good, normal, bad

    init(accuracyMeters: Double) {
        switch accuracyMeters {
        case ..<0:  self = .bad     // negative = invalid fix
        case ..<10: self = .good
        case ..<30: self = .normal
        default:    self = .bad
        }
    }
}

struct Heading: Equatable {
    let degrees: Double            // 0..<360, corrected for device orientation
    var cardinal: Cardinal { Cardinal(degrees: degrees) }
}

enum Cardinal: String {
    case n = "N", ne = "NE", e = "E", se = "SE"
    case s = "S", sw = "SW", w = "W", nw = "NW"

    init(degrees: Double) {
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360 + 22.5)
            .truncatingRemainder(dividingBy: 360)
        let all: [Cardinal] = [.n, .ne, .e, .se, .s, .sw, .w, .nw]
        self = all[Int(normalized / 45)]
    }
}

/// TODO: temperature, pressure, wind speed, humidity (see location.md).
struct Weather: Equatable {}
