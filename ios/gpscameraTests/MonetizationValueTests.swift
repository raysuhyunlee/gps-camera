//
//  MonetizationValueTests.swift
//  Pure cadence logic for monetization nudges (paywall + interstitial ads).
//

import Testing
@testable import gpscamera

struct MonetizationRuleTests {
    // MARK: Paywall - once per session, after the first capture.

    @Test func paywallEarnedOnFirstSessionCaptureOnly() {
        let rules = NudgeRules()
        #expect(!rules.paywallEarned(sessionCaptures: 0))
        #expect(rules.paywallEarned(sessionCaptures: 1))
        #expect(!rules.paywallEarned(sessionCaptures: 2))
        #expect(!rules.paywallEarned(sessionCaptures: 5))
    }

    @Test func paywallSessionCaptureIsConfigurable() {
        var rules = NudgeRules()
        rules.paywallSessionCapture = 3
        #expect(!rules.paywallEarned(sessionCaptures: 1))
        #expect(rules.paywallEarned(sessionCaptures: 3))
    }

    // MARK: Interstitial ads - every 5th session capture, never on zero.

    @Test func adEarnedEveryFifthCapture() {
        #expect(!InterstitialAds.adEarned(sessionCaptures: 0))
        #expect(!InterstitialAds.adEarned(sessionCaptures: 1))
        #expect(!InterstitialAds.adEarned(sessionCaptures: 4))
        #expect(InterstitialAds.adEarned(sessionCaptures: 5))
        #expect(!InterstitialAds.adEarned(sessionCaptures: 6))
        #expect(InterstitialAds.adEarned(sessionCaptures: 10))
        #expect(InterstitialAds.adEarned(sessionCaptures: 15))
    }
}
