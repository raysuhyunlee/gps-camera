# Event

> Draft. Not implemented on any platform yet.

## Status

- 2026-07-06: Initial draft spec. Backend choice and event catalog TBD.

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

- Firebase Analytics + Crashlytics (**TBD** - confirm before implementation)
- No IDFA / ATT prompt; default SDK config only.

### Event Catalog

| Event                | When                         | Params          |
| -------------------- | ---------------------------- | --------------- |
| `capture_completed`  | photo/video capture succeeds | kind            |
| `capture_failed`     | capture errors               | kind, reason    |
| `gallery_opened`     | gallery screen shown         | -               |
| `shared`             | shared media                 | -               |
| `paywall_shown`      | paywall presented            | source          |
| `purchase_completed` | IAP purchase succeeds        | product         |
| `purchase_failed`    | IAP purchase errors          | product, reason |
| `settings_changed`   | a setting value changes      | key, value      |

Global params (included in all events, provided by foundation)
```
firstInstalledAt: datetime
sessionCount: number
photoCaptureCount: number
videoCaptureCount: number
isPro: bool
```

- Crashlytics non-fatals
	- capture pipeline errors
	- store write failures
	* purchase errors


## Implementation

Not started. Planned shape:

```
ios/gpscamera/Domains/Event/
├── Event.swift          - the event catalog enum
├── EventTracking.swift  - seam + no-op tracker
└── FirebaseTracker.swift - backend adapter (TBD)
```

Android: planned.

## Revision History

- 2026-07-06: Initial draft spec.
