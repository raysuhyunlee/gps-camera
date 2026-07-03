//
//  CameraValueTests.swift
//  Pure value-type logic for the camera domain.
//

import Testing
import Foundation
import AVFoundation
import ImageIO
@testable import gpscamera

struct DefaultFilenameProviderTests {
    let sut = DefaultFilenameProvider()
    let date = Date(timeIntervalSince1970: 0)

    @Test func noCollisionReturnsBase() {
        let name = sut.makeName(for: date) { _ in false }
        // IMG_<8 date digits>_<6 time digits>, no auto-number suffix.
        #expect(name.wholeMatch(of: /IMG_\d{8}_\d{6}/) != nil)
    }

    @Test func collisionAppendsIncrementingNumber() {
        let base = sut.makeName(for: date) { _ in false }
        let taken: Set<String> = [base, "\(base)_1"]
        #expect(sut.makeName(for: date) { taken.contains($0) } == "\(base)_2")
    }
}

struct GPSMetadataTests {
    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Date {
        var c = DateComponents()
        (c.year, c.month, c.day, c.hour, c.minute, c.second) = (y, mo, d, h, mi, s)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: c)!
    }

    private func snapshot() -> LocationSnapshot {
        LocationSnapshot(
            coordinate: Coordinate(latitude: 37.5, longitude: -122.3),
            altitude: -5, accuracyMeters: 8,
            heading: Heading(degrees: 90),
            timestamp: date(2026, 7, 3, 14, 5, 9),
            address: nil, weather: nil)
    }

    @Test func refsAndMagnitudes() {
        let gps = GPSMetadata.dictionary(from: snapshot())
        #expect(gps[kCGImagePropertyGPSLatitudeRef as String] as? String == "N")
        #expect(gps[kCGImagePropertyGPSLongitudeRef as String] as? String == "W")
        #expect(gps[kCGImagePropertyGPSLatitude as String] as? Double == 37.5)
        #expect(gps[kCGImagePropertyGPSLongitude as String] as? Double == 122.3)
    }

    @Test func negativeAltitudeIsBelowSeaLevel() {
        let gps = GPSMetadata.dictionary(from: snapshot())
        #expect(gps[kCGImagePropertyGPSAltitudeRef as String] as? Int == 1)
        #expect(gps[kCGImagePropertyGPSAltitude as String] as? Double == 5)
    }

    @Test func headingAndTimestampsAreUTC() {
        let gps = GPSMetadata.dictionary(from: snapshot())
        #expect(gps[kCGImagePropertyGPSImgDirection as String] as? Double == 90)
        #expect(gps[kCGImagePropertyGPSDateStamp as String] as? String == "2026:07:03")
        #expect(gps[kCGImagePropertyGPSTimeStamp as String] as? String == "14:05:09")
    }
}

struct CameraAuthorizationTests {
    @Test(arguments: [
        (AVAuthorizationStatus.authorized, PermissionStatus.authorized),
        (.denied, .denied),
        (.restricted, .denied),
        (.notDetermined, .notDetermined),
    ])
    func mapping(status: AVAuthorizationStatus, expected: PermissionStatus) {
        #expect(CameraAuthorization.map(status) == expected)
    }
}
