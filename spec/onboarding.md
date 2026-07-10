# Onboarding

## Status

- 2026-07-10: Initial spec + iOS implementation. First-run flow (2 value screens
  + 1 permissions page) gated at the composition root; completed flag in the
  foundation settings store.

## Domain Definition

- **Interests**
    - the first-run experience: sell the app's core value, then request the
      camera + location permissions from within the app's own UI (priming)
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
1. Hook         "Prove where you were."        value: verifiable proof
2. Report-ready sample stamped photo           value: report-ready output
3. Permissions  both rationales + Enable ->    location (When In Use) + camera
                requests location, then camera
4. -> Main
```

- One "Enable" button on the permissions page fires `location.requestPermission()`
  then `CameraAuthorization.request` (the OS serializes the two dialogs).
- Non-blocking: after the dialogs resolve, advance to Main regardless of
  grant/deny. A denied camera lands on Main's existing denied state; a denied
  location is handled per the permission-coupled policy (foundation.md).
- No notifications (the app has no push use case today), no paywall.

### Completed flag

- `SettingsStore` key `onboarding.completed` (bool, default false). Set true when
  the flow finishes. The store asserts on unregistered keys, so onboarding
  registers this default at the root (`Onboarding.registerDefaults`).

### Composition

- The root shows onboarding vs Main based on the flag, so Main (and its cold
  permission prompts) does not mount until onboarding completes. Returning
  launches go straight to Main.
- Onboarding is a leaf: consumed by nobody, so it publishes no seam. It consumes
  `LocationProviding` (permission), the camera auth request, `SettingsStore`
  (flag), and `EventTracking` (events), all injected by the root.

### Analytics

- `onboarding_started`, `onboarding_completed`,
  `onboarding_permission` (params: `type` location|camera, `granted`).
  Defined in the event catalog (event.md).

## Implementation

### iOS

```
ios/gpscamera/Domains/Onboarding/
├── Onboarding.swift      - completedKey + registerDefaults(store)
├── OnboardingModel.swift - ObservableObject: step, requestPermissions, complete
└── OnboardingView.swift  - paged UI (2 value pages + permissions page); the
                            report-ready hero is a decoupled SwiftUI mock stamp
ios/gpscamera/RootView.swift - composition-root gate: onboarding vs CameraView
ios/gpscameraTests/
└── OnboardingTests.swift - complete() sets the flag; permissions advance
```

- Copy uses `L()`; English is the key (foundation.md), other languages fall back
  until translated.

Android: planned.

## Revision History

- 2026-07-10: Initial onboarding spec + iOS implementation.

