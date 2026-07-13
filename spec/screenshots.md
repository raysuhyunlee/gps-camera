# Screenshots

## Status

- 2026-07-11: Initial. App Store screenshot automation live on iOS. Two stages:
  in-app demo mode (capture) + Node compose (frame). AI polish step present but
  needs `OPENAI_API_KEY`. Gallery photos are user-supplied. The camera-feed scene
  is picked per App Store storefront (the fastlane locale); all stores currently
  map to the `new-york` scene (Empire State Building skyline).
- 2026-07-12: Localized to all 30 storefronts (`L10n.languages`). Snapfile lists
  the 30 App Store Connect locales; each screen has a translated caption file; the
  overlay address renders natively per non-Latin store. Caption + address drafts
  are machine-translated and need a native review. The overlay compass letter
  (e.g. `S`) is still English everywhere - localizing it is a live-overlay change,
  not screenshot-only (see "Non-interests").

- 2026-07-12: iPad added. The app ships for iPhone + iPad, so the App Store
  requires a screenshot set per device family. Snapfile captures both; composed
  names are device-prefixed so one locale folder holds both sets.

## Domain Definition

- **Interests**
    - Producing App Store screenshots for the store listing
    - Synthesizing an authentic Main screen (the live camera feed is black in the
      simulator) using pre-arranged photos
    - Framing raw captures with device bezel + caption at store dimensions
- **Non-interests**
    - Product UI itself (owned by each domain; demo mode only swaps inputs)
    - Release upload flow (monetization/release-ios skill owns `fastlane release`)
    - Localizing overlay *values* the renderer formats (e.g. the compass letter
      `S`) - that is a live-overlay change (overlay domain), not screenshot-only.
      Demo mode only localizes inputs it injects, like the address.

## Details

Two stages.

### Stage 1: capture (in-app demo mode)

A `#if DEBUG` mode, triggered by launch args, makes the simulator render finished
screens with the real app UI + real overlay renderer. It swaps five inputs:

- **Camera feed** -> a pre-arranged scene photo (the live preview is black in the
  simulator). `CameraView` renders the scene behind the chrome instead of
  `CameraPreview`, as a flexible fill so the controls keep their safe-area insets.
- **Location** -> a curated `LocationSnapshot` (nice address/coords/heading). The
  overlay is a pure function of it, so it renders unchanged. The address is
  localized per store: non-Latin locales get a native spelling from
  `ScreenshotDemo.localizedAddresses`; Latin-script locales keep the scene default.
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
injects, mapped to the app's L10n codes (`ScreenshotDemo.locale`; store `no` ->
L10n `nb`). The UI test picks `<id>` per storefront
via `sceneForStore(Snapshot.deviceLanguage)` (defaults every store to `new-york`);
`SCREENSHOT_SCENE`/`SCREENSHOT_PRO` env override it for manual runs.

A UI test target (`gpscameraScreenshots`) drives navigation and calls fastlane
`snapshot(...)` per screen; `fastlane screenshots` runs it per locale/device.
Raw PNGs land in `ios/fastlane/screenshots_raw/<locale>/`. The `screenshots`
lane takes an optional `languages:` (comma-separated) to capture a subset;
omitted, it uses the full Snapfile list.

### Commands (`ios/justfile`)

Each recipe runs both stages (raw capture + compose):

- `just screenshot-test <lang>` - one language only (e.g. `just screenshot-test ko`)
- `just screenshots` - every language in the Snapfile

### Stage 2: frame (Node compose)

Deterministic: Playwright renders `web/renderer.html` - a device shell holding
the raw capture, with a 2-line caption on a solid background, at 1320x2868
(iPhone 6.9"). `compose.mjs` picks the device profile from the capture size
(iphone-69 or ipad-13; android-phone via `--device`) and the caption typography
from the text script (`--locale auto`): Latin is uppercase display, CJK/RTL/Indic
render in native fonts. It bundles `SF Pro Display Black` (Latin) and `Pretendard`
(Korean) as data-URI fonts when installed, else falls back to system fonts.
`build.mjs` frames every raw capture using per-locale captions; output lands in
`ios/fastlane/screenshots/<locale>/` as `<device>-<screen>.png` (`iphone-01Main.png`,
`ipad-01Main.png`) - one folder holds every device, and deliver routes each file
to its display type by pixel size. Optional AI polish (`enhance.mjs`, OpenAI
`gpt-image-1` / "ducktape") runs per screen when `OPENAI_API_KEY` is set.

### Assets (user-supplied)

- `scenes/screenshot-scene-<id>.jpg` - camera-feed backgrounds; `-Scene <id>`.
- `gallery/screenshot-gallery-<n>.jpg` - gallery grid captures (n = 1, 2, ...).
- Match each scene to a `LocationSnapshot` in `ScreenshotDemo.scenes`.
- Add native address spellings per non-Latin store in
  `ScreenshotDemo.localizedAddresses` (keyed by scene, then L10n code).
- Map a storefront to a non-default scene in `ScreenshotUITests.scenesByStore`
  (keyed by fastlane locale); unlisted stores use `new-york`.
- Add a caption file per store in `screenshots/captions/<locale>.json` (keyed by
  App Store Connect locale); missing files fall back to `en-US.json`.

### Upload

`fastlane release` auto-includes `fastlane/screenshots/` when non-empty
(`skip_screenshots` toggles off the glob). Kept out of git as a build artifact.

## Implementation

### iOS

```
ios/gpscamera/Screenshot/
├── ScreenshotDemo.swift        - launch-arg switch: active, scene, forcePro, locale, curated snapshot + localized addresses
├── DemoCaptureStore.swift      - CaptureStoreBrowsing over bundled demo photos (no photo-library grant needed)
└── Assets/                     - user-supplied scenes/ + gallery/ (bundled, DEBUG)
ios/gpscameraScreenshots/       - UI test target (shared scheme)
├── ScreenshotUITests.swift     - drives Main/Gallery/Settings; picks scene per store; calls snapshot()
└── SnapshotHelper.swift        - fastlane helper
ios/fastlane/
├── Snapfile                    - devices (iPhone 6.9" + iPad 13") + 30 store languages + status-bar override
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
├── compose.mjs        - frame one capture via Playwright; device + locale-typography profiles
├── build.mjs          - frame every raw capture using captions/<locale>.json
├── enhance.mjs        - optional OpenAI gpt-image-1 polish (needs OPENAI_API_KEY)
├── web/renderer.html  - device shell + caption template
└── captions/          - one <locale>.json per store (line1/line2 + bg per screen); 30 locales
```

## Revision history

- 2026-07-11: Initial screenshot automation (demo mode + compose pipeline + skill).
- 2026-07-11: Fix demo captures - scene fill keeps controls in the safe area
  (was overlapping the status bar / cropping the bottom), seed the lens set, and
  pose Settings (Overlay) + Gallery (multi-select) in the UI test.
- 2026-07-11: AI polish switched from Gemini to OpenAI `gpt-image-1`
  ("ducktape"); env var now `OPENAI_API_KEY`.
- 2026-07-11: Bundled `demo` scene added - Empire State Building night skyline
  (from Top of the Rock); curated snapshot set to that vantage.
- 2026-07-11: Scene now selected per storefront via `ScreenshotUITests`
  `sceneForStore`/`scenesByStore` (defaults all stores to `new-york`); the old
  `demo` scene id/default is gone.
- 2026-07-12: Wait for the async map snapshot before capturing Main - the UI
  test polls the overlay's `overlayMapReady` a11y marker (DEBUG-only) so the map
  box is not blank; times out and shoots anyway if the snapshot never lands.
- 2026-07-12: All 30 storefronts (`L10n.languages`). Snapfile lists the 30 ASC
  locales; one caption file per store; overlay address localized per non-Latin
  store (`ScreenshotDemo.localizedAddresses`); `no` store maps to L10n `nb`.
  Caption + address drafts are machine-translated, pending native review.
- 2026-07-12: Compose rewrite - device profiles (iphone-69/ipad-13/android-phone)
  auto-picked from capture size, locale-aware caption typography (uppercase Latin
  display, native CJK/RTL/Indic fonts), bundled `SF Pro Display Black`/`Pretendard`
  data-URI fonts with system fallback. Adds `image-size` dep.
- 2026-07-12: `just` recipes for the full pipeline (raw capture + compose):
  `screenshot-test <lang>` (one language) and `screenshots` (all). The
  `screenshots` fastlane lane now accepts an optional `languages:` override.
- 2026-07-12: iPad Pro 13" added to the Snapfile (the app targets iPhone + iPad,
  so the App Store requires both sets). `build.mjs` now prefixes each composed
  file with its device, which previously collided on the shared screen key.
- 2026-07-12: Settings pose fixed for iPad - the scroll-to-Overlay drag was
  relative to the window, which on iPad lands on the camera behind the centred
  form sheet, so the sheet never scrolled. It now drags the list itself, by a
  point distance both devices share.
