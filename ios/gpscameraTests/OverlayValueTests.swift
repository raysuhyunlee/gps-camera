//
//  OverlayValueTests.swift
//  Pure value-type logic for the overlay domain (formatting, anchor mapping).
//

import Testing
import Foundation
import UIKit
@testable import gpscamera

struct OverlayFormatterTests {
    let coordinate = Coordinate(latitude: 37.5326, longitude: -122.0246)

    @Test func coordinatesLatLon() {
        #expect(OverlayFormatter.coordinates(coordinate, format: .latLon)
                == "37.532600, -122.024600")
    }

    @Test func coordinatesDMS() {
        #expect(OverlayFormatter.coordinates(coordinate, format: .dms)
                == "37\u{00B0}31'57.4\"N 122\u{00B0}01'28.6\"W")
    }

    @Test func altitudeMetricAndImperial() {
        #expect(OverlayFormatter.altitude(38.6, unit: .metric) == "39 m")
        #expect(OverlayFormatter.altitude(38.6, unit: .imperial) == "127 ft")
    }

    @Test func accuracyMetricAndImperial() {
        #expect(OverlayFormatter.accuracy(8.4, unit: .metric) == "\u{00B1}8 m")
        #expect(OverlayFormatter.accuracy(8.4, unit: .imperial) == "\u{00B1}28 ft")
    }

    @Test func headingDegreesAndCardinal() {
        #expect(OverlayFormatter.heading(Heading(degrees: 275)) == "275\u{00B0} W")
    }

    @Test func timeFollowsLocale() {
        let date = Date(timeIntervalSince1970: 0)
        #expect(OverlayFormatter.time(date, locale: Locale(identifier: "en_GB"),
                                      timeZone: .gmt)
                == "01/01/1970, 0:00:00")
        #expect(OverlayFormatter.time(date, locale: Locale(identifier: "de_DE"),
                                      timeZone: .gmt)
                == "1.1.1970, 0:00:00")
    }
}

struct OverlayAnchorTests {
    let orientations: [UIDeviceOrientation] =
        [.portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown]

    /// World top-left relocates with the device so it stays at the same world
    /// corner (landscapeLeft: world top edge = screen trailing edge).
    @Test func topLeadingTracksWorldCorner() {
        let anchor = OverlayAnchor.topLeading
        #expect(anchor.screenUnit(for: .portrait) == CGPoint(x: 0, y: 0))
        #expect(anchor.screenUnit(for: .landscapeLeft) == CGPoint(x: 1, y: 0))
        #expect(anchor.screenUnit(for: .landscapeRight) == CGPoint(x: 0, y: 1))
        #expect(anchor.screenUnit(for: .portraitUpsideDown) == CGPoint(x: 1, y: 1))
    }

    @Test func centerIsOrientationInvariant() {
        for orientation in orientations {
            #expect(OverlayAnchor.center.screenUnit(for: orientation)
                    == CGPoint(x: 0.5, y: 0.5))
        }
    }

    @Test func worldUnitInvertsScreenUnit() {
        for anchor in OverlayAnchor.allCases {
            for orientation in orientations {
                let roundTrip = OverlayAnchor(nearest: OverlayAnchor.worldUnit(
                    fromScreen: anchor.screenUnit(for: orientation),
                    orientation: orientation))
                #expect(roundTrip == anchor)
            }
        }
    }

    @Test func nearestSnapsInThirds() {
        #expect(OverlayAnchor(nearest: CGPoint(x: 0.1, y: 0.9)) == .bottomLeading)
        #expect(OverlayAnchor(nearest: CGPoint(x: 0.5, y: 0.4)) == .center)
        #expect(OverlayAnchor(nearest: CGPoint(x: 0.8, y: 0.2)) == .topTrailing)
    }
}
