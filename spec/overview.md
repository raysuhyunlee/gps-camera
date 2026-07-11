# Overview

> This is not a single domain. This document holds product context, the cross-domain architecture, and the Settings screen composition. 
> Shared infrastructure lives in `foundation.md`.

## Status

- 2026-07-11: Screenshot automation live on iOS: `#if DEBUG` demo mode
  synthesizes an authentic Main screen (pre-arranged scene + curated overlay)
  for App Store captures, framed by a Node compose stage (screenshots.md).
- 2026-07-10: Onboarding domain live on iOS: first-run flow (1 value screen + 1
  permissions page) gated by `RootView` at the composition root; camera +
  location requested from within onboarding (onboarding.md).
- 2026-07-08: L10n live; Settings fully populated (General/Language, feedback,
  about now live alongside camera/overlay/filename/monetization). 30 languages.
- 2026-07-07: Nudges live on iOS: `NudgeOrchestrator` owns the
  `UsageMetrics.onCapture` hook at the root and dispatches paywall nudge /
  review attempt / ad (monetization.md "Nudge orchestrator").
- 2026-07-07: Ads live on iOS: AdMob interstitial every 10th photo for free
  users, triggered through foundation's `UsageMetrics.onPhotoCapture` hook
  bound at the root (monetization.md "Ads").
- 2026-07-06: Restore purchase row live in Settings (order 90); overlay
  enforces watermark force-on for free (entitlement wired into
  `OverlayRenderer` at the root).
- 2026-07-06: Event domain live on iOS (Firebase Analytics + Crashlytics);
  `EventTracking` wired into camera, gallery, monetization, and the settings
  store at the root.
- 2026-07-06: Paywall + RevenueCat IAP live on iOS (`ProStore` replaces the
  entitlement stub at the root); locked pro rows open the paywall via the
  `PaywallProviding` seam.
- 2026-07-05: Gallery domain live on iOS; camera/gallery seams added to the
  wiring (`CaptureStoreBrowsing`, `GalleryProviding`).
- 2026-07-06: Pro banner live on Main (thin tappable line) and in Settings
  (thicker banner with CTA, section order 0).
- 2026-07-05: Settings screen live on iOS (sheet from Main's gear control):
  registry-rendered sections for camera (20) / overlay (30) / filename (40).
- 2026-06-30: Initial spec. Architecture and settings framework defined.

## Product

- App name: GPS Camera(**TBD**)
- Platforms: iOS (SwiftUI), Android (planned)
- One-liner: a camera that burns GPS + location metadata into photos/videos.

### Business Model

- One-time: **$12** (lifetime Pro)
- Monthly: **$4**
- Reference: competitor sells one-time at ₩15,000
- Pro unlocks:
    - Remove ads
    - Remove watermark
    - Overlay style settings
    - Filename settings
- Free interstitial ad

## Screen Map

Screens are assemblies of domains. A domain is never split across docs.

| Screen     | Composed of                                                                                                   |
| ---------- | ------------------------------------------------------------------------------------------------------------- |
| Onboarding | `onboarding` (shown once on first launch, before Main; requests camera + location)                            |
| Main       | `camera` + `location` + `overlay` + `monetization` (pro banner)                                               |
| Settings | `monetization` (pro banner, restore) + per-domain `SettingsSection`s + foundation (language, feedback, about); opened from Main's settings gear |
| Gallery  | `gallery`                                                                                                     |
| Paywall  | `monetization`                                                                                                |

## Software Architecture

- Three layers. 
- Keep it simple
	- value-type models
	- protocol seams only where a domain is consumed by another
	- one composition root (the app entry point).

```
Composition Root (the app entry point)
  └─ wires domains into screens
Domains (self-contained feature modules)
  onboarding · camera · location · overlay · filename · gallery · monetization · event
  each owns: models · logic · UI · SettingsSection
Foundation (shared)
```

### Domain wiring (provider → consumer)

Only these cross-domain seams exist. Everything else is internal.

- **location**
	- publishes `LocationSnapshot` 
	- coords, altitude, accuracy, compass, timestamp, weather
	- Pure provider; depends on no other domain.
- **overlay** 
	- consumes `LocationSnapshot` + its settings
	- renders an overlay layer.
- **camera** 
	- consumes `overlay` (render into capture), `location` (EXIF write),
  `filename` (name the output), `gallery` (recent-thumbnail control on Main).
	- publishes the capture store (browse/delete), read by `gallery`.
- **gallery**
	- consumes the capture store; renders the grid, viewer, and the
  recent-thumbnail control hosted on Main.
- **filename** 
	- consumes `LocationSnapshot` + its template settings
	* output name.
- **monetization** 
	- publishes `Entitlement` (`.free` / `.pro`), read by every domain for gating
	- publishes the paywall screen (`PaywallProviding`), presented by Main for
	  locked pro settings rows
	- publishes the Main pro banner (`ProBannerProviding`); the Settings banner
	  ships as its `SettingsSection` (Control.custom)
	- owns ads and the nudge orchestrator; the orchestrator receives
	  foundation's usage-metrics `onCapture` hook (bound at the root) and
	  dispatches paywall nudge / review attempt / ad.
- **event**
	- publishes `EventTracking`, injected into any domain that fires analytics
	  events or records non-fatals
	- pure sink; depends on no other domain.
- **onboarding**
	- the first-run flow; presented by the root on first launch, gating Main
	  behind the `onboarding.completed` flag (in `SettingsStore`)
	- consumes `LocationProviding` (permission request), the camera auth request
	  (`CameraAuthorization`), and `EventTracking`
	- leaf: consumed by nobody, so it publishes no seam.

Seams are narrow protocols (DIP), e.g. `LocationProviding`, `OverlayRendering`,
`CaptureStoreBrowsing`, `GalleryProviding`, `EntitlementProviding`. Domains
never import each other's UI.

### SOLID (minimally)

- **SRP** - a domain owns only its own logic, UI, and settings.
- **OCP** - new domain registers its `SettingsSection` and seams; no screen edits.
- **LSP** - seams are one-purpose protocols (`LocationProviding`, …).
- **DIP** - screens/domains depend on seam protocols, resolved at the composition root.
- Keep simple: no DI container. The composition root constructs and injects.

## Settings (composition)

- The Settings screen knows no domain. 
- It renders whatever `SettingsSection`s the registry holds; each domain owns and contributes its own. 
- The framework (schema, registry, store, gating) is defined in `foundation.md`.
- Section ordering is owned here, at the composition root (domains stay unaware of placement)

| order | Section                        | Owner          |
| ----- | ------------------------------ | -------------- |
| 0     | Pro banner                     | `monetization` |
| 10    | General → Language             | `foundation`   |
| 20    | Capture → Photo / Video        | `camera`       |
| 30    | Overlay                        | `overlay`      |
| 40    | Filename                       | `filename`     |
| 90    | Restore purchase               | `monetization` |
| 91    | Send feedback                  | `foundation`   |
| 92    | About                          | `foundation`   |

## Revision History

- 2026-07-10: Onboarding domain added (first-run value priming + permission
  requests); `RootView` gates onboarding vs Main at the root (onboarding.md).
- 2026-07-08: `L10n.shared.setLanguage` wired in `SettingsStore.onSet` at the
  root; `FoundationSettingsProvider` registered (General/Language order 10,
  feedback order 91, about order 92). Settings screen now fully populated.
- 2026-07-07: Nudge orchestrator wired at the root (owns both usage-metrics
  capture hooks; ads now reached through it).
- 2026-07-07: Ads wired at the root (`InterstitialAds`, usage-metrics hook);
  camera no longer consumes monetization directly.
- 2026-07-06: Event domain implemented on iOS and wired at the root.
- 2026-07-06: Event domain added to the architecture (spec draft only).
- 2026-07-06: Monetization wired at the root (`ProStore` entitlement + paywall).
- 2026-07-05: Gallery domain wired (capture-store seam, Main thumbnail control).
- 2026-07-05: Settings screen composed at the root (store, registry,
  entitlement stub); gear entry point on Main.
- 2026-06-30: Initial overview and architecture. Foundation split to its own doc.
