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
    /// Lifetime capture counts (photos + videos) that earn a paywall nudge
    /// (free users only).
    var paywallCaptureMilestones: Set<Int> = [25, 50, 100]
    /// In-app review: attempted on the first capture of a session, from this
    /// session on. The OS decides whether the prompt actually shows.
    var reviewMinSession = 3
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

    /// Lifetime-capture milestones, free users only. The lifetime count passes
    /// each milestone once, so fired milestones need no persistence.
    private func showPaywallIfEarned() -> Bool {
        let captures = metrics.photoCaptureCount + metrics.videoCaptureCount
        guard store.entitlement == .free,
              rules.paywallCaptureMilestones.contains(captures),
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
