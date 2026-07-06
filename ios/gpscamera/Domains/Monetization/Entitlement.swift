//
//  Entitlement.swift
//  Monetization - the entitlement seam every domain reads for gating
//  (overview.md "Domain wiring"). Provided by ProStore; ads not yet built.
//

import Foundation

nonisolated enum Entitlement: Equatable { case free, pro }

protocol EntitlementProviding {
    nonisolated var entitlement: Entitlement { get }
}

/// Fixed entitlement for previews and tests. Flip to `.free` to exercise the
/// lock UI.
nonisolated struct FixedEntitlement: EntitlementProviding {
    var entitlement: Entitlement = .pro
}
