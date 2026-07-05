//
//  FilenameValueTests.swift
//  Pure value-type logic for the filename domain.
//

import Testing
import Foundation
@testable import gpscamera

struct DefaultFilenameProviderTests {
    let sut = DefaultFilenameProvider()   // defaults: IMG_ + date, auto-number on
    let date = Date(timeIntervalSince1970: 0)
    let snapshot = LocationSnapshot(
        coordinate: Coordinate(latitude: 37.5326, longitude: 127.0246),
        altitude: 38.2, accuracyMeters: 8.5,
        heading: Heading(degrees: 275), timestamp: Date(timeIntervalSince1970: 0),
        address: "12 Hannam-daero, Yongsan-gu, Seoul", weather: nil)

    @Test func defaultsRenderPrefixPlusDate() {
        let name = sut.makeName(for: date, snapshot: nil) { _ in false }
        #expect(name.wholeMatch(of: /IMG_\d{8}_\d{6}/) != nil)
    }

    @Test func collisionAppendsIncrementingNumber() {
        let base = sut.makeName(for: date, snapshot: nil) { _ in false }
        let taken: Set<String> = [base, "\(base)_1"]
        #expect(sut.makeName(for: date, snapshot: nil) { taken.contains($0) } == "\(base)_2")
    }

    @Test func autoNumberOffKeepsCollidingName() {
        var settings = FilenameSettings()
        settings.autoNumber = false
        let sut = DefaultFilenameProvider(fixed: settings)
        let name = sut.makeName(for: date, snapshot: nil) { _ in true }
        #expect(name.wholeMatch(of: /IMG_\d{8}_\d{6}/) != nil)
    }

    @Test func templateRendersTokensInOrder() {
        var settings = FilenameSettings()
        settings.template = [.altitude, .date, .coordinates]
        settings.prefix = ""
        settings.dateFormat = "yyyyMMdd"
        let sut = DefaultFilenameProvider(fixed: settings)
        let name = sut.makeName(for: date, snapshot: snapshot) { _ in false }
        #expect(name == "38m_19700101_37.532600_127.024600")
    }

    @Test func unavailableTokensAreSkipped() {
        var settings = FilenameSettings()
        settings.template = [.date, .address, .altitude]
        settings.dateFormat = "yyyyMMdd"
        let sut = DefaultFilenameProvider(fixed: settings)
        #expect(sut.makeName(for: date, snapshot: nil) { _ in false } == "IMG_19700101")
    }

    @Test func prefixSuffixAndSanitization() {
        var settings = FilenameSettings()
        settings.template = [.address]
        settings.prefix = "trip/"
        settings.suffix = "_v1"
        let sut = DefaultFilenameProvider(fixed: settings)
        let name = sut.makeName(for: date, snapshot: snapshot) { _ in false }
        #expect(!name.contains("/"))
        #expect(name.hasSuffix("_v1"))
        #expect(name.hasPrefix("trip-"))
    }

    @Test func emptyResultFallsBack() {
        var settings = FilenameSettings()
        settings.template = [.address]
        settings.prefix = ""
        let sut = DefaultFilenameProvider(fixed: settings)
        #expect(sut.makeName(for: date, snapshot: nil) { _ in false } == "IMG")
    }
}
