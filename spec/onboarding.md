# Onboarding

## Status

- 2026-07-15: Permission copy explains that access is required for the app to
  work properly; the permission action is named Continue.
- 2026-07-13: Photos replaces the mic on the permissions page; the action
  requests location -> camera -> photos. Photo access is required to capture at
  all (camera.md "Storage"); the mic is requested on the first recording.
- 2026-07-12: Permissions page adds a mic row; the action requests
  location -> camera -> mic. Mic is optional (silent video on deny).
- 2026-07-10: Initial spec + iOS implementation. First-run flow (1 value screen
  + 1 permissions page) gated at the composition root; completed flag in the
  foundation settings store.

## Domain Definition

- **Interests**
    - the first-run experience: sell the app's core value, then request the
      camera + location + photo permissions from within the app's own UI (priming)
    - a persisted "completed" flag so the flow shows once
- **Non-interests**
    - owning permissions or auth state (location + camera domains own those)
    - any feature logic, Pro conversion, notifications

Core value sold (north star): verifiable proof - a photo that defends the user
to someone who wasn't there. Field/professional users first (construction,
survey, delivery, trades, real estate); travel/personal secondary.

## Details

### Flow

Universal, linear, shown once on first launch:

```
1. Value        sample stamped photo + "Prove where you were." + 3 proof bullets
                (burn location/time, holds up as evidence, drop into your report)
2. Permissions  three rationales + Continue -> requests location, then camera, then photos
3. -> Main
```

- One "Continue" button requests location, camera, then photos. Each request starts
  only after the previous authorization callback resolves.
- Non-blocking: after the dialogs resolve, advance to Main regardless of
  grant/deny. A denied camera lands on Main's existing denied state; a denied
  location is handled per the permission-coupled policy (foundation.md); denied
  photos leaves the shutter nudging to iOS Settings, since a capture has nowhere
  to go (camera.md "Permissions").
- The **mic is not asked here**: it belongs to the first recording, not to a
  first-run page most users answer before ever opening video mode (camera.md
  "Audio").
- No notifications (the app has no push use case today), no paywall.

### Completed flag

- `SettingsStore` key `onboarding.completed` (bool, default false). Set true when
  the flow finishes. The store asserts on unregistered keys, so onboarding
  registers this default at the root (`Onboarding.registerDefaults`).
- The debug surface (foundation.md dev backdoor) can reset the flag; onboarding
  shows again on next launch (`RootView` reads the flag at startup).

### Composition

- The root shows onboarding vs Main based on the flag, so Main (and its cold
  permission prompts) does not mount until onboarding completes. Returning
  launches go straight to Main.
- `RootView.onOnboarded` fires when the flow finishes (or at once for returning
  launches); the root uses it to start ATT after the onboarding prompts, so the
  ATT dialog never stacks on the onboarding page (monetization.md "ATT").
- Onboarding is a leaf: consumed by nobody, so it publishes no seam. It consumes
  `LocationProviding` (permission), the camera + photo-library auth requests,
  `SettingsStore` (flag), and `EventTracking` (events), all injected by the root.

### Analytics

- `onboarding_started`, `onboarding_completed`,
  `onboarding_permission` (params: `type` location|camera|photos, `granted`).
  Defined in the event catalog (event.md).

## Implementation

### iOS

```
ios/gpscamera/Domains/Onboarding/
├── Onboarding.swift      - completedKey + registerDefaults(store)
├── OnboardingModel.swift - ObservableObject: step, requestPermissions, complete
└── OnboardingView.swift  - paged UI (1 value page + permissions page); the
                            value-page hero is a decoupled SwiftUI mock stamp
ios/gpscamera/RootView.swift - composition-root gate: onboarding vs CameraView
ios/gpscameraTests/
└── OnboardingTests.swift - completion flag + sequential permission requests
```

- Copy uses `L()`; English is the key (foundation.md), other languages fall back
  until translated.

Android: planned.

## Revision History

- 2026-07-15: Permission rationale updated + action renamed Continue.
- 2026-07-13: Photos replaces the mic on the permissions page + request sequence.
- 2026-07-12: Mic added to the permissions page + request sequence.
- 2026-07-10: Initial onboarding spec + iOS implementation.
