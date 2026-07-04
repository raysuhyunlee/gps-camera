//
//  CameraValueTests.swift
//  Pure value-type logic for the camera domain.
//

import Testing
import Foundation
import AVFoundation
import ImageIO
import SwiftUI
import UIKit
@testable import gpscamera

struct EXIFGPSMetadataTests {
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

struct MicrophoneAuthorizationTests {
    @Test(arguments: [
        (AVAuthorizationStatus.authorized, PermissionStatus.authorized),
        (.denied, .denied),
        (.restricted, .denied),
        (.notDetermined, .notDetermined),
    ])
    func mapping(status: AVAuthorizationStatus, expected: PermissionStatus) {
        #expect(MicrophoneAuthorization.map(status) == expected)
    }
}

struct ISO6709Tests {
    @Test func signedFixedWidthWithAltitudeAndSlash() {
        let snapshot = LocationSnapshot(
            coordinate: Coordinate(latitude: 37.5, longitude: -122.3),
            altitude: -5, accuracyMeters: 8, heading: nil,
            timestamp: Date(), address: nil, weather: nil)
        #expect(ISO6709.string(from: snapshot) == "+37.5000-122.3000-5.000/")
    }
}

struct CameraOrientationTests {
    @Test func controlAngleCounterRotatesControls() {
        #expect(CameraOrientation.controlAngle(for: .portrait) == .degrees(0))
        #expect(CameraOrientation.controlAngle(for: .landscapeLeft) == .degrees(90))
        #expect(CameraOrientation.controlAngle(for: .landscapeRight) == .degrees(-90))
        #expect(CameraOrientation.controlAngle(for: .portraitUpsideDown) == .degrees(180))
    }

    @Test func videoRotationAngleIsUprightPerOrientation() {
        #expect(CameraOrientation.videoRotationAngle(for: .portrait) == 90)
        #expect(CameraOrientation.videoRotationAngle(for: .landscapeLeft) == 180)
        #expect(CameraOrientation.videoRotationAngle(for: .landscapeRight) == 0)
        #expect(CameraOrientation.videoRotationAngle(for: .portraitUpsideDown) == 270)
    }

    @Test func anchorAlignmentTracksWorldTop() {
        #expect(CameraOrientation.anchorAlignment(for: .portrait) == .top)
        #expect(CameraOrientation.anchorAlignment(for: .landscapeLeft) == .trailing)
        #expect(CameraOrientation.anchorAlignment(for: .landscapeRight) == .leading)
        #expect(CameraOrientation.anchorAlignment(for: .portraitUpsideDown) == .bottom)
    }
}
