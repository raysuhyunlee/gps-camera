//
//  MonetizationValueTests.swift
//  Pure cadence logic for monetization nudges (paywall + interstitial ads).
//

import Testing
@testable import gpscamera

struct MonetizationRuleTests {
    // MARK: Nudge - once per session, on the first capture. Power-of-three
    // sessions (3, 9, 27, ...) earn the review attempt; the rest the paywall.

    @Test func nudgeOnFirstSessionCaptureOnly() {
        let rules = NudgeRules()
        #expect(rules.nudge(sessionCaptures: 0, sessionCount: 1) == nil)
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 1) != nil)
        #expect(rules.nudge(sessionCaptures: 2, sessionCount: 1) == nil)
        #expect(rules.nudge(sessionCaptures: 5, sessionCount: 3) == nil)
    }

    @Test func powerOfThreeSessionsEarnReviewOthersPaywall() {
        let rules = NudgeRules()
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 1) == .paywall)
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 2) == .paywall)
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 3) == .review)
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 4) == .paywall)
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 6) == .paywall)
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 9) == .review)
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 27) == .review)
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 81) == .review)
    }

    @Test func nudgeSessionCaptureIsConfigurable() {
        var rules = NudgeRules()
        rules.nudgeSessionCapture = 3
        #expect(rules.nudge(sessionCaptures: 1, sessionCount: 1) == nil)
        #expect(rules.nudge(sessionCaptures: 3, sessionCount: 1) == .paywall)
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
