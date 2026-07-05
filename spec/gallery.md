# Gallery

## Status

- 2026-07-05: iOS gallery implemented: grid, full-screen pager (share/delete),
  recent-thumbnail control hosted on Main. Reads the capture store through the
  `CaptureStoreBrowsing` seam (camera).
- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**: browsing captured media via a built-in gallery.
- **Non-interests**: capture (camera), overlay, export formatting.

## Details

- Built-in gallery (in-app), not the system photo library picker.
- Grid of captured photos/videos, newest first; tap to view full screen.
- Full-screen viewer: horizontal paging, videos play inline; filename shown as
  the title (tap for the untruncated name).
- Per-item actions: share (share sheet), delete (with confirmation).
- Reads the capture store as defined in camera.md (Android: own `MediaStore`
  entries; iOS: app-private store) - never the full system library, no read
  permission.
- `_original` copies (camera.md) are listed like any other item: the store is
  their only in-app access point.
- Recent-capture thumbnail: a Main-screen control published to camera via
  `GalleryProviding`; shows the latest capture and opens the gallery.
- Refresh: the capture store posts `captureStoreDidChange` on write/delete;
  gallery views refresh on it and on appearance.

## Settings

None.

## Implementation

### iOS

```
ios/gpscamera/Domains/Gallery/
├── GalleryProviding.swift  - seam consumed by camera: thumbnail control; Gallery owns the model
├── GalleryItem.swift       - value type: url + kind (photo/video), next-selection helper
├── GalleryModel.swift      - items over CaptureStoreBrowsing, delete, thumbnail decode + cache
├── GalleryView.swift       - grid screen + recent-thumbnail control
└── GalleryDetailView.swift - full-screen pager: photo/video pages, share, delete
ios/gpscameraTests/
└── GalleryValueTests.swift - item kind + next-selection tests
```

Android: planned.

## Revision History

- 2026-07-05: iOS gallery v1 (grid, viewer, share/delete, Main thumbnail).
- 2026-06-30: Initial gallery spec.
