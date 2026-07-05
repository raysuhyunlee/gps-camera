# Gallery

## Status

- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**: browsing captured media via a built-in gallery.
- **Non-interests**: capture (camera), overlay, export formatting.

## Details

- Built-in gallery (in-app), not the system photo library picker.
- Grid of captured photos/videos; tap to view full screen.
- Per-item actions: share, delete.
- Reads the capture store as defined in camera.md (Android: own `MediaStore`
  entries; iOS: app-private store) - never the full system library, no read
  permission.

## Settings

None.

## Revision History

- 2026-06-30: Initial gallery spec.
