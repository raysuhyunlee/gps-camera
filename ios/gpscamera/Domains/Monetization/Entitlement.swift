//
//  Entitlement.swift
//  Monetization - the entitlement seam every domain reads for gating
//  (overview.md "Domain wiring"). IAP, paywall, ads: not yet built.
//

import Foundation

nonisolated enum Entitlement { case free, pro }

protocol EntitlementProviding {
    nonisolated var entitlement: Entitlement { get }
}

/// Development stub until IAP lands: everything unlocked so pro settings are
/// testable. Flip to `.free` to exercise the lock UI.
nonisolated struct FixedEntitlement: EntitlementProviding {
    var entitlement: Entitlement = .pro
}
