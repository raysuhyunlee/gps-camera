---
name: localize
description: Create localized copies of app content for a given scope (screenshots, settings, paywall, metadata, or any UI domain). Use when the user says "localize", "localize the paywall", "translate the settings", or "update localizations". Localizes (not literal translation) into every target language via one subagent per language.
---

# Localize

Produce localized copies for one scope across every target language. Localize for
meaning, culture, and store trends -- never literal translation.

Paths are relative to repo root. Sources of truth: `spec/foundation.md` (L10n), `spec/screenshots.md` (captions), the domain doc for the scope.

## 1. Resolve the scope

- If the user gave no scope, ask which one (`screenshots`, `settings`, `paywall`,
  `metadata`, or a UI domain: camera, overlay, filename, gallery, onboarding).
- Map it with the table below to a source, target files, and locale set.

| Scope          | Source (English)                              | Targets                                   | Locale set |
| -------------- | --------------------------------------------- | ----------------------------------------- | ---------- |
| screenshots    | `screenshots/captions/en-US.json`             | `screenshots/captions/<locale>.json`      | store      |
| metadata       | `ios/fastlane/metadata/en-US/*`               | `ios/fastlane/metadata/<locale>/*`        | store      |
| settings       | `/* Settings */` group in `Localizable.strings` | `ios/gpscamera/<lang>.lproj/Localizable.strings` | app  |
| paywall        | `/* Monetization */` group                    | same                                      | app        |
| camera/overlay/filename/gallery/onboarding | matching `/* ... */` group      | same                                      | app        |

- App UI strings: the English text IS the key. There is no `en.lproj`. Read the
  key side of any existing `.lproj` file, sliced by the `/* Domain */` comment,
  to get the English source list. Localize only the values in that group; leave
  other groups untouched.

## 2. Gather context (once, before spawning)

- Read the scope's domain doc + `README.md` / `spec/overview.md` for product
  positioning, benefits, and tone.
- Assemble the English source strings for the scope. Confirm the list with the
  user before spawning if the scope is large or ambiguous.

## 3. Localize

Target-language codes:

- **App** (29, lproj dir names): `ar cs da de el es fi fr he hi hu id it ja ko ms
  nb nl pl pt-BR ro ru sv th tr uk vi zh-Hans zh-Hant`
- **Store** (29, ASC codes): `ko ja zh-Hans zh-Hant es-ES pt-BR de-DE fr-FR it
  nl-NL ru tr sv da fi no pl cs hu ro uk vi id ms th hi el ar-SA he`
- Same languages, different spelling. Store->app: `de-DE->de es-ES->es fr-FR->fr
  nl-NL->nl no->nb ar-SA->ar`; the rest match.

## 4. Review and report

- After localization is finished, spot-check a few languages (RTL + one CJK + one
  European) for format integrity and tone.
- Report a short summary: scope, languages done, and one sample line each for a
  couple of locales. Let the user review before they commit.

## Notes

- This skill only rewrites content files -- it adds no keys and no new locales.
  To add a language, add its `.lproj` / caption / metadata folder first.
