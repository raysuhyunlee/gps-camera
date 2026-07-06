//
//  ProStore.swift
//  Monetization - RevenueCat: offerings, purchase, restore, live entitlement
//  (monetization.md "Products & purchase").
//

import Combine
import Foundation
import RevenueCat

/// RevenueCat project config. Debug uses the Test Store key; release the
/// Apple App Store key. TODO: replace with the gpscamera project's real keys.
private nonisolated enum RevenueCatConfig {
    static let entitlementID = "pro"
    #if DEBUG
    static let apiKey = "test_YQpNLSfXMOlOtohsDKmMllJcZHY"
    #else
    static let apiKey = "appl_REPLACE_WITH_GPSCAMERA_KEY"
    #endif
}

/// Loads the current offering's packages and derives `Entitlement` from the
/// customer info stream. The entitlement is mirrored into a lock-protected box
/// (capture pipelines read the seam off the main actor) and persisted so pro
/// survives offline launches.
final class ProStore: ObservableObject, EntitlementProviding {
    @Published private(set) var packages: [Package] = []
    /// True once an offerings load attempt finished (drives the loading state).
    @Published private(set) var loaded = false
    /// Store page for managing an active subscription; nil when there is none
    /// to manage (free, lifetime).
    @Published private(set) var managementURL: URL?

    private let cached: EntitlementBox
    private let cachedProKey = "monetization.cachedPro"
    /// Fires paywall_shown / purchase events (event.md). Previews and tests
    /// keep the no-op default; the root injects the real tracker.
    let events: EventTracking

    nonisolated var entitlement: Entitlement { cached.value }

    init(events: EventTracking = NoopTracker()) {
        self.events = events
        // Last persisted entitlement until RevenueCat answers (offline reads).
        cached = EntitlementBox(
            UserDefaults.standard.bool(forKey: cachedProKey) ? .pro : .free)
        if !Purchases.isConfigured {
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        }
        // Fires on launch and on every purchase/restore/renewal/expiry.
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(info)
            }
        }
        Task { await loadOfferings() }
    }

    /// Idempotent; retries on next call while `packages` is still empty.
    func loadOfferings() async {
        guard packages.isEmpty else { return }
        let offering = try? await Purchases.shared.offerings().current
        packages = (offering?.availablePackages ?? [])
            .sorted { $0.storeProduct.price < $1.storeProduct.price }   // monthly, lifetime
        loaded = true
    }

    /// A purchase or restore that completed without becoming pro. `inactive`
    /// means the store transaction went through but the `pro` entitlement did
    /// not activate - a product <-> entitlement mapping problem in the
    /// RevenueCat dashboard.
    nonisolated enum PurchaseError: Error { case inactive }

    /// True = pro is active; false = the user cancelled. Throws on store
    /// errors and on `inactive` (see above).
    func purchase(_ package: Package) async throws -> Bool {
        let product = package.storeProduct.productIdentifier
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return false }
            apply(result.customerInfo)
            guard entitlement == .pro else { throw PurchaseError.inactive }
            events.track(.purchaseCompleted(product: product))
            return true
        } catch {
            events.track(.purchaseFailed(product: product,
                                         reason: Event.reason(error)))
            events.record(error, keys: ["product": product])
            throw error
        }
    }

    /// Restore purchase: re-validates the entitlement with RevenueCat.
    /// True = pro is active; false = nothing to restore.
    func restore() async throws -> Bool {
        apply(try await Purchases.shared.restorePurchases())
        return entitlement == .pro
    }

    private func apply(_ info: CustomerInfo) {
        managementURL = info.managementURL
        let pro = info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
        UserDefaults.standard.set(pro, forKey: cachedProKey)
        if cached.value != (pro ? Entitlement.pro : .free) {
            cached.value = pro ? .pro : .free
            objectWillChange.send()
            // An open Settings screen re-evaluates its gated rows (foundation).
            NotificationCenter.default.post(name: .settingsGatingChanged, object: nil)
        }
    }
}

/// Lock-protected mirror so `entitlement` is readable off the main actor.
private nonisolated final class EntitlementBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Entitlement

    init(_ initial: Entitlement) { stored = initial }

    var value: Entitlement {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}
