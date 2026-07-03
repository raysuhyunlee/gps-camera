//
//  FilenameValueTests.swift
//  Pure value-type logic for the filename domain.
//  (Provider currently lives under Domains/Camera; moves with the domain.)
//

import Testing
import Foundation
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
