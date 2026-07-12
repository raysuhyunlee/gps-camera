# GPS Camera

## Directory Structure

```
- android  # android source code
- ios      # ios source code
- spec     # tech spec (source-of-truth)
```

## Spec Index

Domain documents live under `/spec`. Each is the source-of-truth for its domain.

| Doc                    | Domain                                                                                       |
| ---------------------- | -------------------------------------------------------------------------------------------- |
| `spec/overview.md`     | Product, branding, BM, screen map, software architecture, settings composition               |
| `spec/onboarding.md`   | First-run flow: value priming + camera/location permission requests                          |
| `spec/foundation.md`   | Shared infra: l10n, theme, design system, settings framework, usage metrics, feedback, about |
| `spec/camera.md`       | Capture surface: photo/video, lens, flash, front/back, capture settings, EXIF writing        |
| `spec/location.md`     | GPS + sensor provider: accuracy, coords, altitude, compass, time, weather                    |
| `spec/overlay.md`      | Overlay items, drag positioning, styling, preview, render-onto-media                         |
| `spec/filename.md`     | Filename templating: tokens, prefix/suffix, date format, auto-number                         |
| `spec/gallery.md`      | Built-in gallery                                                                             |
| `spec/monetization.md` | Pro subscription, paywall, IAP products, gating, ads, nudge orchestrator                     |
| `spec/event.md`        | Analytics event catalog, Crashlytics, Firebase dispatch                                      |
| `spec/screenshots.md`  | App Store screenshot automation: in-app demo mode (capture) + Node compose (frame)           |
