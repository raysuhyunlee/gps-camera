---
name: release-ios
description: Ship an iOS App Store release. Use when the user says "release ios", "ship it to App Store", or "publish to App Store". 
Runs preflight checks, git tag version, then runs fastlane release.
---

# Release

Orchestrate an App Store release for the iOS app. Do the steps in order. Stop and ask the user if any check fails. Never skip a check.

Paths are relative to repo root. All fastlane commands run from `ios/`.

## 1. Preflight: version bumped

- Read `MARKETING_VERSION` from `ios/gpscamera.xcodeproj/project.pbxproj`.
- Read the latest semver tag: `git tag --list 'v*' --sort=-v:refname | head -1`.
- If a tag `v<MARKETING_VERSION>` already exists, the version was NOT bumped. Stop. Tell the user to bump `MARKETING_VERSION` in Xcode (target > General > Version) and re-run.
- If no tags exist yet, this is the first release — continue.

## 2. Preflight: release note written

- Read `ios/fastlane/metadata/en-US/release_notes.txt`.
- If it is empty, or still equals the seed placeholder
  `Thanks for using GPS Camera! This release includes bug fixes and improvements.`,
  the note is unwritten. Stop and ask the user for the English release note.
- Show the user the English note and confirm it is final before continuing.
- Reject notes over 4000 characters (App Store per-locale limit).

## 3. Commit + tag

- `git add ios/gpscamera.xcodeproj/project.pbxproj ios/fastlane/metadata`
- `git commit -m "Release v<MARKETING_VERSION>"`
- `git tag v<MARKETING_VERSION>`

The tree must be clean after this — `fastlane release` runs `ensure_git_status_clean`.

## 4. Run fastlane

- `cd ios && bundle exec fastlane release` (or `just release`).
- This bumps the build number, builds a signed archive, and uploads to App Store Connect (What's New + binary; no review submission).
- After it succeeds, the build-number bump in `project.pbxproj` is uncommitted. Commit it: `git commit -am "Bump build number"` (amend onto the release commit is fine too).
- Push: `git push && git push --tags`.

## Notes

- Requires `ios/fastlane/.env` (API key credentials) and `ios/fastlane/AuthKey.p8`. If missing, `fastlane release` fails at auth — tell the user to set them up (see `ios/fastlane/.env.example`).
- App Store shows release notes only on updates, not the first version.
- The store listing is English-only: `ios/fastlane/metadata/` holds `en-US` alone, and the App Store serves it to every storefront. Do not add other locale folders unless the full listing (name, subtitle, keywords, description) is localized too — App Store Connect rejects a new localization that has only release notes.
