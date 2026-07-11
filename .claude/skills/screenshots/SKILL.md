---
name: screenshots
description: Generate App Store screenshots for the iOS app. Use when the user says "make screenshots", "app store screenshots", "update screenshots", or "generate ASO screenshots". Captures authentic Main/Gallery/Settings screens in demo mode, then frames them with captions (+ optional AI polish).
---

# Screenshots

Generate App Store screenshots. Two stages: capture authentic screens from the
simulator in demo mode, then frame them. Source of truth: `spec/screenshots.md`.

Paths are relative to repo root. fastlane runs from `ios/`; compose runs from `screenshots/`.

## 1. Preflight: scene photos present

- Check `ios/gpscamera/Screenshot/Assets/scenes/` for `screenshot-scene-<id>.jpg`
  and `.../gallery/` for `screenshot-gallery-<n>.jpg`.
- If none exist, stop and ask the user to drop real photos in (see the README
  there). The demo Main screen is black without a scene photo.
- For each scene id used, confirm a matching `LocationSnapshot` entry exists in
  the `scenes` table in `ios/gpscamera/Screenshot/ScreenshotDemo.swift` so the
  overlay address/coordinates fit the photo. Default is Seoul.

## 2. Benefit discovery (captions)

- Read `README.md` + `spec/overview.md` for the product's core benefits.
- Draft a 2-line caption + background color per hero screen (Main, Gallery,
  Settings) and write `screenshots/captions/<locale>.json` for each target
  locale. Keys are the screen ids: `01Main`, `02Gallery`, `03Settings`.
- Show the user the captions and confirm before continuing.

## 3. Capture (stage 1)

- `cd ios && bundle exec fastlane screenshots`.
- Runs the `gpscameraScreenshots` UI test in demo mode per locale/device from
  `ios/fastlane/Snapfile`; raw PNGs land in `ios/fastlane/screenshots_raw/<locale>/`.
- Sanity-check one raw Main shot: it must show the scene photo + overlay card,
  not black. If black, the scene asset is missing or `-Scene` id is wrong.

## 4. Frame (stage 2, deterministic)

- `cd screenshots && npm install` (first run only), then
  `npx playwright install chromium` (first run only).
- `node build.mjs` — frames every raw capture with its caption, writing
  store-ready 1320x2868 PNGs to `ios/fastlane/screenshots/<locale>/`.

## 5. AI polish (optional)

- If the user wants the premium look and `GEMINI_API_KEY` is set, run
  `node enhance.mjs --input <png> --output <png>` per final screen (Nano Banana /
  Gemini 2.5 Flash Image). Review each output; image models vary per run, so
  re-run for variants and keep the best. Skip this step if no key.

## 6. Upload

- Screenshots upload with the next release: `ios/fastlane/Fastfile`'s `release`
  lane auto-includes `fastlane/screenshots/` when non-empty.
- To upload screenshots only (no binary), run
  `cd ios && bundle exec fastlane deliver --skip_binary_upload true --skip_metadata true`.

## Notes

- Demo mode is `#if DEBUG` only; it never ships in Release.
- `screenshots_raw/`, `screenshots/`, and `build/` are git-ignored build outputs.
- Devices/locales are set in `ios/fastlane/Snapfile` (default: iPhone 6.9",
  en-US/ko/ja). Expand toward the ~30 metadata locales when ready.
