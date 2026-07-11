# Screenshots

## Status

- 2026-07-11: Initial. App Store screenshot automation live on iOS. Two stages:
  in-app demo mode (capture) + Node compose (frame). AI polish step present but
  needs `GEMINI_API_KEY`. Scene/gallery photos are user-supplied.

## Domain Definition

- **Interests**
    - Producing App Store screenshots for the store listing
    - Synthesizing an authentic Main screen (the live camera feed is black in the
      simulator) using pre-arranged photos
    - Framing raw captures with device bezel + caption at store dimensions
- **Non-interests**
    - Product UI itself (owned by each domain; demo mode only swaps inputs)
    - Release upload flow (monetization/release-ios skill owns `fastlane release`)

## Details

Two stages.

### Stage 1: capture (in-app demo mode)

A `#if DEBUG` mode, triggered by launch args, makes the simulator render finished
screens with the real app UI + real overlay renderer. It swaps five inputs:

- **Camera feed** -> a pre-arranged scene photo (the live preview is black in the
  simulator). `CameraView` renders the scene behind the chrome instead of
  `CameraPreview`, as a flexible fill so the controls keep their safe-area insets.
- **Location** -> a curated `LocationSnapshot` (nice address/coords/heading). The
  overlay is a pure function of it, so it renders unchanged.
- **Lens set** -> seeded `[.ultraWide, .wide, .tele]` (no real session runs), so
  the 0.5x/1x/2x selector renders on Main.
- **Entitlement** -> forced `.pro` (default) for clean shots; `-ScreenshotPro 0`
  keeps `.free` for a paywall/banner shot.
- **Onboarding + gallery** -> onboarding skipped; the capture store seeded with
  bundled demo photos so the gallery grid + Main thumbnail populate.

The UI test also poses each hero screen: Settings is scrolled to lead with the
Overlay section, and Gallery is put in multi-select with two items picked (to
show batch share/delete).

Launch args (read by `ScreenshotDemo`): `-ScreenshotDemo 1 -Scene <id>
[-ScreenshotPro 0|1]`. Language follows the standard `-AppleLanguages` fastlane
injects, mapped to the app's L10n codes.

A UI test target (`gpscameraScreenshots`) drives navigation and calls fastlane
`snapshot(...)` per screen; `fastlane screenshots` runs it per locale/device.
Raw PNGs land in `ios/fastlane/screenshots_raw/<locale>/`.

### Stage 2: frame (Node compose)

Deterministic: Playwright renders `web/renderer.html` - a device bezel holding
the raw capture, with a 2-line caption on a solid background, at 1320x2868
(iPhone 6.9"). `build.mjs` frames every raw capture using per-locale captions;
output lands in `ios/fastlane/screenshots/<locale>/`. Optional AI polish
(`enhance.mjs`, Gemini 2.5 Flash Image / Nano Banana) runs per screen when
`GEMINI_API_KEY` is set.

### Assets (user-supplied)

- `scenes/screenshot-scene-<id>.jpg` - camera-feed backgrounds; `-Scene <id>`.
- `gallery/screenshot-gallery-<n>.jpg` - gallery grid captures (n = 1, 2, ...).
- Match each scene to a `LocationSnapshot` in `ScreenshotDemo.scenes`.

### Upload

`fastlane release` auto-includes `fastlane/screenshots/` when non-empty
(`skip_screenshots` toggles off the glob). Kept out of git as a build artifact.

## Implementation

### iOS

```
ios/gpscamera/Screenshot/
├── ScreenshotDemo.swift        - launch-arg switch: active, scene, forcePro, locale, curated snapshot
├── ScreenshotSeed.swift        - seeds Captures/ with bundled demo photos
└── Assets/                     - user-supplied scenes/ + gallery/ (bundled, DEBUG)
ios/gpscameraScreenshots/       - UI test target (shared scheme)
├── ScreenshotUITests.swift     - drives Main/Gallery/Settings, calls snapshot()
└── SnapshotHelper.swift        - fastlane helper
ios/fastlane/
├── Snapfile                    - devices + languages + status-bar override
└── Fastfile                    - `screenshots` lane; release auto-includes shots

# DEBUG-gated swaps in existing files:
#   gpscameraApp.swift          - skip onboarding, set locale, seed gallery
#   Domains/Camera/CameraView.swift, CameraController.swift - scene swap, force authorized
#   Domains/Location/LocationProvider.swift - seed curated snapshot
#   Domains/Monetization/ProStore.swift - pin entitlement
```

### Compose (Node)

```
screenshots/
├── compose.mjs        - frame one capture (device bezel + caption) via Playwright
├── build.mjs          - frame every raw capture using captions/<locale>.json
├── enhance.mjs        - optional Gemini polish (needs GEMINI_API_KEY)
├── web/renderer.html  - device shell + caption template
└── captions/          - per-locale line1/line2 + bg per screen
```

## Revision history

- 2026-07-11: Initial screenshot automation (demo mode + compose pipeline + skill).
- 2026-07-11: Fix demo captures - scene fill keeps controls in the safe area
  (was overlapping the status bar / cropping the bottom), seed the lens set, and
  pose Settings (Overlay) + Gallery (multi-select) in the UI test.
