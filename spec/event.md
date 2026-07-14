# Event

## Status

- 2026-07-14: Firebase Analytics and Crashlytics collection disabled in debug
  builds and enabled in release builds.
- 2026-07-07: `review_requested` added; `paywall_shown` gains the `nudge`
  source (monetization nudge orchestrator).
- 2026-07-07: `ad_shown` added (monetization interstitial).
- 2026-07-06: iOS implementation done.

## Domain Definition

- **Interests**
	- the catalog of analytics events: what fires, when, with which parameters
	- crash reporting (Crashlytics): non-fatal error recording, crash keys
	- dispatching events to the backend SDK
- **Non-interests**
	- usage metrics: managed by foundation
	- business decisions made from events (dashboards, remote config)
	- logging for local debugging

## Details

### Architecture

- Event owns the catalog: a single enum of every event with typed parameters.
  Other domains fire events; they never define them.
- Publishes the `EventTracking` seam, injected into consumers at the
  composition root. Domains never import the backend SDK.
- A no-op tracker backs previews and tests.

```
EventTracking {            // the seam every consumer receives
    track(Event)           // analytics event
    record(error, keys)    // non-fatal to Crashlytics
}

Event = enum, one case per event, typed parameters
    e.g. .captureCompleted(kind: photo|video)
```

### Backend

- Firebase Analytics + Crashlytics
- Collection is disabled in debug builds and enabled in release builds.
- No IDFA / ATT prompt; default SDK config only.
- The adapter configures Firebase only when `GoogleService-Info.plist` is in
  the bundle; otherwise every call is a no-op (builds and tests need no plist).

### Event Catalog

| Event                   | When                                             | Params                                                      |
| ----------------------- | ------------------------------------------------ | ----------------------------------------------------------- |
| `capture_completed`     | photo/video capture succeeds                     | kind                                                        |
| `capture_failed`        | capture errors                                   | kind, reason                                                |
| `gallery_opened`        | gallery screen shown                             | -                                                           |
| `shared`                | shared media                                     | -                                                           |
| `paywall_shown`         | paywall presented                                | source: main_banner, settings_banner, locked_setting, nudge |
| `purchase_completed`    | IAP purchase succeeds                            | product                                                     |
| `purchase_failed`       | IAP purchase errors                              | product, reason                                             |
| `settings_changed`      | a setting value changes                          | key, value                                                  |
| `ad_shown`              | interstitial ad presented                        | -                                                           |
| `review_requested`      | in-app review attempt (OS may not show a prompt) | -                                                           |
| `onboarding_started`    | first-run flow appears                           | -                                                           |
| `onboarding_completed`  | first-run flow finishes                          | -                                                           |
| `onboarding_permission` | a permission dialog resolves in onboarding       | type: location, camera, photos; granted                     |

Global params (included in all events, provided by foundation)
```
firstInstalledAt: datetime
sessionCount: number
photoCaptureCount: number
videoCaptureCount: number
isPro: bool
```

- Crashlytics non-fatals (keys)
	- capture pipeline errors, incl. store write failures (capture_kind)
	- purchase errors (product)

### Firing points

- camera: capture results (completed/failed + non-fatal), capture counters
- gallery: screen appear (gallery_opened), share tap (shared)
- monetization: paywall appear with source, purchase result in `ProStore`,
  interstitial present in `InterstitialAds` (ad_shown + load/show non-fatals),
  review attempt in `NudgeOrchestrator` (review_requested)
- onboarding: flow start/finish + each permission result (`OnboardingModel`)
- settings_changed: `SettingsStore.onSet` hook, bound to the tracker at the root
- failure reasons are compact `domain:code` (`Event.reason`)

## Implementation

### iOS

```
ios/gpscamera/Domains/Event/
├── Event.swift           - the event catalog enum + name/params mapping
├── EventTracking.swift   - seam + NoopTracker (previews, tests)
└── FirebaseTracker.swift - Firebase adapter; inert without the plist;
                            merges global params from UsageMetrics
ios/gpscameraTests/
└── EventValueTests.swift - catalog mapping + UsageMetrics counters
```

- Global params come from foundation's `UsageMetrics` (foundation.md).
- SPM: `firebase-ios-sdk` (FirebaseAnalytics, FirebaseCrashlytics), app target only.

Android: planned.

## Revision History

- 2026-07-14: Analytics and Crashlytics collection made release-only.
- 2026-07-10: `onboarding_started` / `onboarding_completed` /
  `onboarding_permission` events (onboarding.md).
- 2026-07-07: `review_requested` event + `nudge` paywall source (nudge
  orchestrator, monetization.md).
- 2026-07-07: `ad_shown` event (ads implementation, monetization.md).
- 2026-07-06: iOS implementation (catalog, seam, Firebase adapter, wiring).
- 2026-07-06: Initial draft spec.
