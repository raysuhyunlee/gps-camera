//
//  NudgeOrchestrator.swift
//  Monetization - data-driven nudge rules over usage metrics (monetization.md
//  "Nudge orchestrator"). Decides what a finished capture earns: paywall
//  nudge, review prompt, or ad - at most one per capture, paywall first.
//

import StoreKit
import SwiftUI

/// The rule set. Edit values here; call sites never change. Rules never
/// distinguish photos from videos - a capture is a capture.
struct NudgeRules {
    /// Session capture index (photos + videos) that earns a paywall nudge -
    /// the paywall shows once per session, after this many captures (free users
    /// only). 1 = after the first capture of every session.
    var paywallSessionCapture = 1
    /// In-app review: attempted on the first capture of a session, from this
    /// session on. The OS decides whether the prompt actually shows.
    var reviewMinSession = 3

    /// Whether a finished capture at this session index earns the paywall nudge.
    /// Pure so the cadence is unit-testable without presenting UI.
    func paywallEarned(sessionCaptures: Int) -> Bool {
        sessionCaptures == paywallSessionCapture
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
    /// The review attempt fires at most once per session.
    private var reviewRequested = false

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
        let paywallShown = showPaywallIfEarned()
        ads.captureSaved(suppressingAd: paywallShown)
        if !paywallShown { requestReviewIfEarned() }
    }

    /// First capture of the session, free users only. The session count (reset
    /// each launch) hits the trigger index exactly once per session, so it
    /// needs no persistence and fires at most once per session.
    private func showPaywallIfEarned() -> Bool {
        let sessionCaptures = metrics.sessionPhotoCount + metrics.sessionVideoCount
        guard store.entitlement == .free,
              rules.paywallEarned(sessionCaptures: sessionCaptures),
              let top = InterstitialAds.topViewController()
        else { return false }
        top.present(UIHostingController(
            rootView: PaywallView(store: store, source: .nudge)), animated: true)
        return true
    }

    /// First capture of the session, from the reviewMinSession-th session on.
    /// A capture that showed the paywall defers the attempt to the next one.
    private func requestReviewIfEarned() {
        guard !reviewRequested, metrics.sessionCount >= rules.reviewMinSession,
              let scene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive })
        else { return }
        reviewRequested = true
        AppStore.requestReview(in: scene)
        events.track(.reviewRequested)
    }
}
