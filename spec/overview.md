# Overview

> This is not a single domain. This document holds product context, the cross-domain architecture, and the Settings screen composition. 
> Shared infrastructure lives in `foundation.md`.

## Status

- 2026-07-06: Paywall + RevenueCat IAP live on iOS (`ProStore` replaces the
  entitlement stub at the root); locked pro rows open the paywall via the
  `PaywallProviding` seam.
- 2026-07-05: Gallery domain live on iOS; camera/gallery seams added to the
  wiring (`CaptureStoreBrowsing`, `GalleryProviding`).
- 2026-07-05: Settings screen live on iOS (sheet from Main's gear control):
  registry-rendered sections for camera (20) / overlay (30) / filename (40).
  Pending sections: pro banner, General/Language, restore, feedback, about.
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

| Screen   | Composed of                                                                                                   |
| -------- | ------------------------------------------------------------------------------------------------------------- |
| Main     | `camera` + `location` + `overlay` + `monetization` (pro banner)                                               |
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
  camera · location · overlay · filename · gallery · monetization
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
  `filename` (name the output), `gallery` (recent-thumbnail control on Main),
  `monetization` (capture-count → ad trigger).
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
	- owns ads and the nudge orchestrator.

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

- 2026-07-06: Monetization wired at the root (`ProStore` entitlement + paywall).
- 2026-07-05: Gallery domain wired (capture-store seam, Main thumbnail control).
- 2026-07-05: Settings screen composed at the root (store, registry,
  entitlement stub); gear entry point on Main.
- 2026-06-30: Initial overview and architecture. Foundation split to its own doc.
