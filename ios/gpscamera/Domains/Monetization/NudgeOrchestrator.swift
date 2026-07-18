//
//  NudgeOrchestrator.swift
//  Monetization - data-driven nudge rules over usage metrics (monetization.md
//  "Nudge orchestrator"). Decides what a finished capture earns: paywall
//  nudge, review prompt, or ad - at most one per capture.
//

import StoreKit
import SwiftUI

/// The rule set. Edit values here; call sites never change. Rules never
/// distinguish photos from videos - a capture is a capture.
struct NudgeRules {
    /// Session capture index (photos + videos) that earns the session's one
    /// nudge. 1 = the first capture of every session.
    var nudgeSessionCapture = 1

    enum Nudge { case paywall, review }

    /// What the capture at this session index earns, if anything. Sessions
    /// whose ordinal is a power of three (3, 9, 27, ...) earn the review
    /// attempt; every other session earns the paywall nudge (free users only -
    /// entitlement is the caller's concern). Mutually exclusive so the review
    /// prompt never competes with the paywall in the same session. Pure so
    /// the cadence is unit-testable without presenting UI.
    func nudge(sessionCaptures: Int, sessionCount: Int) -> Nudge? {
        guard sessionCaptures == nudgeSessionCapture else { return nil }
        return isPowerOfThree(sessionCount) ? .review : .paywall
    }

    private func isPowerOfThree(_ n: Int) -> Bool {
        var n = n
        guard n >= 3 else { return false }
        while n.isMultiple(of: 3) { n /= 3 }
        return n == 1
    }
}

/// Bound to `UsageMetrics.onCapture` at the root, so nudges run after a
/// capture has saved, never during one. Every capture forwards to the ad
/// trigger; a paywall nudge suppresses that capture's ad.
final class NudgeOrchestrator {
    private let rules: NudgeRules
    private let metrics: UsageMetrics
    private let store: ProStore
    private let ads: InterstitialAds
    private let events: EventTracking

    init(rules: NudgeRules = NudgeRules(), metrics: UsageMetrics,
         store: ProStore, ads: InterstitialAds,
         events: EventTracking = NoopTracker()) {
        self.rules = rules
        self.metrics = metrics
        self.store = store
        self.ads = ads
        self.events = events
    }

    func captureCompleted() {
        let sessionCaptures = metrics.sessionPhotoCount + metrics.sessionVideoCount
        var paywallShown = false
        switch rules.nudge(sessionCaptures: sessionCaptures,
                           sessionCount: metrics.sessionCount) {
        case .paywall: paywallShown = showPaywall()
        case .review: requestReview()
        case nil: break
        }
        ads.captureSaved(suppressingAd: paywallShown)
    }

    /// Free users only. The session capture count (reset each launch) hits the
    /// trigger index exactly once per session, so this needs no persistence
    /// and fires at most once per session.
    private func showPaywall() -> Bool {
        guard store.entitlement == .free,
              let top = InterstitialAds.topViewController()
        else { return false }
        top.present(UIHostingController(
            rootView: PaywallView(store: store, source: .nudge)), animated: true)
        return true
    }

    /// The OS decides whether the prompt actually shows.
    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        AppStore.requestReview(in: scene)
        events.track(.reviewRequested)
    }
}
