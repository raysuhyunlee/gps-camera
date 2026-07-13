# Gallery

## Status

- 2026-07-13: Media now lives in the system photo library (camera.md "Storage"),
  so items are keyed by asset id, not file URL. The in-app delete confirmation is
  gone - Photos runs its own. Share exports the file out of the library first.
- 2026-07-10: Multi-select live on the grid ("Select" or long press): batch
  share + delete.
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
- Per-item actions: share (share sheet), delete.
- Multi-select: "Select" or a long press on a cell enters selection mode (the
  long-pressed item starts selected); tap toggles an item, the title shows the
  count, the bottom bar shares or deletes the set. "Cancel" leaves the mode.
  Selection is view state.
- Reads the capture store as defined in camera.md "Storage": the app's **own
  captures only**, never the user's whole library.
- Delete has **no in-app confirmation**: the system photo library runs its own
  before removing an asset, and a cancel leaves the items in place. Two
  confirmations for one action is worse than one.
- Share exports the media out of the photo library to a file first, so the shared
  file carries the app's filename. The export is cached for the session.
- `_original` copies (camera.md) are listed like any other item.
- Recent-capture thumbnail: a Main-screen control published to camera via
  `GalleryProviding`; shows the latest capture and opens the gallery.
- Refresh: the capture store posts `captureStoreDidChange` on write/delete;
  gallery views refresh on it and on appearance. Anything deleted straight from
  the system photo library drops out on the next read.

## Settings

None.

## Implementation

### iOS

```
ios/gpscamera/Domains/Gallery/
├── GalleryProviding.swift  - seam consumed by camera: thumbnail control; Gallery owns the model
├── GalleryItem.swift       - value type: CaptureEntry + kind (photo/video), next-selection + selected helpers
├── GalleryModel.swift      - items over CaptureStoreBrowsing, delete (single/batch), thumbnail + exported-file caches
├── GalleryView.swift       - grid screen + multi-select + share sheet + recent-thumbnail control
└── GalleryDetailView.swift - full-screen pager: photo/video pages, share, delete
ios/gpscameraTests/
└── GalleryValueTests.swift - item kind + next-selection + selection tests
```

The store owns media access (the media lives in the photo library, not in a
directory the gallery can walk); the gallery owns presentation and caching.

Android: planned.

## Revision History

- 2026-07-13: Items keyed by photo-library asset id; in-app delete confirmation
  removed (the library confirms); share exports the file first.
- 2026-07-10: Multi-select on the grid ("Select" or long press); batch share + delete.
- 2026-07-05: iOS gallery v1 (grid, viewer, share/delete, Main thumbnail).
- 2026-06-30: Initial gallery spec.
