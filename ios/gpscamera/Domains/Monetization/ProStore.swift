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

    private let cached: EntitlementBox
    private let cachedProKey = "monetization.cachedPro"

    nonisolated var entitlement: Entitlement { cached.value }

    init() {
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

    /// Returns true when the purchase ends in an active pro entitlement.
    func purchase(_ package: Package) async -> Bool {
        guard let result = try? await Purchases.shared.purchase(package: package),
              !result.userCancelled else { return false }
        apply(result.customerInfo)
        return entitlement == .pro
    }

    /// Restore purchase: re-validates the entitlement with RevenueCat.
    func restore() async -> Bool {
        guard let info = try? await Purchases.shared.restorePurchases() else {
            return false
        }
        apply(info)
        return entitlement == .pro
    }

    private func apply(_ info: CustomerInfo) {
        let pro = info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
        UserDefaults.standard.set(pro, forKey: cachedProKey)
        if cached.value != (pro ? Entitlement.pro : .free) {
            cached.value = pro ? .pro : .free
            objectWillChange.send()
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
