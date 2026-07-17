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
                == "01/01/1970, 00:00:00")
        #expect(OverlayFormatter.time(date, locale: Locale(identifier: "de_DE"),
                                      timeZone: .gmt)
                == "1.1.1970, 00:00:00")
    }
}

struct OverlayLayerMetricsTests {
    @Test func usesActualPictureWidth() {
        let portrait = CGSize(width: 1170, height: 2532)
        let landscape = CGSize(width: 2532, height: 1170)

        #expect(OverlayLayerMetrics.mediaScale(for: portrait) == 3)
        #expect(abs(OverlayLayerMetrics.mediaScale(for: landscape) - 6.4923) < 0.0001)
        #expect(OverlayLayerMetrics.mediaMargin(for: portrait) == 48)
        #expect(abs(OverlayLayerMetrics.mediaMargin(for: landscape) - 103.8769) < 0.0001)
    }

    @Test func maximumReferenceLayerFitsBetweenMediaMargins() {
        let media = CGSize(width: 1170, height: 2532)
        let reference = CGSize(width: OverlayLayerMetrics.maximumWidth, height: 100)
        let result = OverlayLayerMetrics.mediaLayerSize(reference, in: media)

        #expect(result.width == 1074)
        #expect(result.height == 300)
        #expect(result.width + 2 * OverlayLayerMetrics.mediaMargin(for: media)
                == media.width)
    }

    @Test func oversizedLayerIsClampedToActualMediaWidth() {
        let media = CGSize(width: 1170, height: 2532)
        let result = OverlayLayerMetrics.mediaLayerSize(
            CGSize(width: 500, height: 100), in: media)

        #expect(result.width == 1074)
        #expect(abs(result.height - 214.8) < 0.001)
    }
}

/// overlay.md "Settings": free cannot disable the watermark; pro can.
/// Revocation flips the stored toggle back on so Settings shows the real state.
@MainActor struct OverlayGatingTests {
    private func makeStore() -> SettingsStore {
        let suite = "overlay-gating-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)
        _ = SettingsRegistry(providers: [OverlaySettingsProvider()],
                             order: [:], store: store)
        return store
    }

    @Test func freeFlipsStoredWatermarkBackOn() {
        let store = makeStore()
        store.set(.bool(false), for: OverlaySettingKey.itemWatermark)
        let renderer = OverlayRenderer(store: store,
                                       entitlement: FixedEntitlement(entitlement: .free))
        #expect(renderer.settings.showWatermark)
        #expect(store.bool(OverlaySettingKey.itemWatermark))
    }

    @Test func proKeepsWatermarkOff() {
        let store = makeStore()
        store.set(.bool(false), for: OverlaySettingKey.itemWatermark)
        let renderer = OverlayRenderer(store: store,
                                       entitlement: FixedEntitlement(entitlement: .pro))
        #expect(!renderer.settings.showWatermark)
        #expect(!store.bool(OverlaySettingKey.itemWatermark))
    }

    /// Purchase while running (free -> pro) turns the watermark off once.
    @Test func becomingProTurnsWatermarkOff() async {
        let store = makeStore()
        let entitlement = MutableEntitlement(.free)
        let renderer = OverlayRenderer(store: store, entitlement: entitlement)
        #expect(renderer.settings.showWatermark)

        entitlement.entitlement = .pro
        NotificationCenter.default.post(name: .settingsGatingChanged, object: nil)
        await Task.yield()   // gating sink delivers on the main queue

        #expect(!renderer.settings.showWatermark)
        #expect(!store.bool(OverlaySettingKey.itemWatermark))

        // Stays user-editable afterwards: turning it back on sticks.
        store.set(.bool(true), for: OverlaySettingKey.itemWatermark)
        await Task.yield()   // store onChange also delivers on the main queue
        #expect(renderer.settings.showWatermark)
        #expect(store.bool(OverlaySettingKey.itemWatermark))
    }
}

private final class MutableEntitlement: EntitlementProviding, @unchecked Sendable {
    var entitlement: Entitlement
    init(_ initial: Entitlement) { entitlement = initial }
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
