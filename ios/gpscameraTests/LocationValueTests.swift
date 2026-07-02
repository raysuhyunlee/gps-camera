//
//  LocationValueTests.swift
//  Pure value-type logic for the location domain.
//

import Testing
@testable import gpscamera

struct AccuracyLevelTests {
    @Test(arguments: [
        (-1.0, AccuracyLevel.bad),   // negative = invalid fix
        (0.0, .good),
        (9.99, .good),
        (10.0, .normal),             // boundary: not < 10
        (29.99, .normal),
        (30.0, .bad),                // boundary: not < 30
        (100.0, .bad),
    ])
    func classify(meters: Double, expected: AccuracyLevel) {
        #expect(AccuracyLevel(accuracyMeters: meters) == expected)
    }
}

struct CardinalTests {
    @Test(arguments: [
        (0.0, Cardinal.n),
        (22.4, .n),      // upper edge of the N band
        (22.5, .ne),     // start of NE
        (45.0, .ne),
        (90.0, .e),
        (135.0, .se),
        (180.0, .s),
        (225.0, .sw),
        (270.0, .w),
        (315.0, .nw),
        (337.5, .n),     // wraps back into N
        (360.0, .n),
        (-45.0, .nw),    // negative degrees
        (810.0, .e),     // > 360 (720 + 90)
    ])
    func mapping(degrees: Double, expected: Cardinal) {
        #expect(Cardinal(degrees: degrees) == expected)
    }
}
