//
//  EventTracking.swift
//  Event - the seam every consumer receives (event.md "Architecture").
//  Injected at the composition root; domains never import the backend SDK.
//

protocol EventTracking {
    /// Analytics event.
    func track(_ event: Event)
    /// Non-fatal to Crashlytics with contextual keys.
    func record(_ error: Error, keys: [String: String])
}

/// Backs previews and tests.
final class NoopTracker: EventTracking {
    func track(_ event: Event) {}
    func record(_ error: Error, keys: [String: String]) {}
}
