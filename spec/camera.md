# Camera

## Status

- 2026-07-03: iOS Main screen + photo pipeline implemented
  (`ios/gpscamera/Domains/Camera`). Deferred: video mode + audio, capture
  settings (settings framework), overlay burn (overlay domain), saveOriginal
  duplication.
- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**
	- the capture surface (Main screen)
	- capture controls and settings
	- the capture pipeline
	- EXIF writing
- **Non-interests**
	- overlay content/rendering (overlay)
	- location data
	- naming

## Details

### Main screen surface

Hosts, but does not own, the other domains' Main-screen pieces:

- Camera preview (this domain)
- GPS accuracy indicator — from `location` (`accuracyLevel`)
- Live overlay — from `overlay`
- Pro banner — from `monetization`

### Controls

- Photo / video mode switch
- Lens / field-of-view switch (ultra-wide / wide / tele, as available)
- Flash toggle
- Front / back switch

### Device Orientation
- Controls and live overlay rotate based on current device orientation
- When `camera.orientationLock` is on, rotation is frozen at the current
  orientation (capture proceeds in the locked orientation)

### Capture pipeline

1. Capture frame (photo) or stream (video).
2. If `overlay.enabled`, burn the rendered overlay layer (from `OverlayRendering`).
3. If `camera.exif.location`, write `LocationSnapshot` into EXIF.
4. Name the output via `filename`.
5. Persist (see **Storage** below). If `camera.photo.saveOriginal`, also save the
   un-overlaid original under the same name with a fixed `_original` suffix
   (e.g. `IMG_001` -> `IMG_001_original`). This marker is fixed and is distinct
   from the user's `filename.suffix` setting.
6. Notify usage metrics (photo count) → `monetization` may present an interstitial.

### Storage

The capture store is the gallery's source of truth. Its shape varies by platform:

- **Android** - single copy in `MediaStore` (DCIM/Pictures)
	- they show in the system gallery
	- The app reads back its own entries with no permission
- **iOS** - app-private store is the source of truth
	* When `camera.saveToPhotos` is on, media is copied to the Camera Roll
		* Use 2x storage. Sort of back-up.

Neither platform ever requests full photo-library **read** access.

- **Durability**: each capture is written atomically
	- a burst is never buffered whole in memory
	- Bulk capture must not drop or corrupt files.

### Audio

- The microphone is attached **only in video mode**, and its permission is
  requested lazily on first video use.
- Photo capture never configures the audio session
	- the user's music/podcast keeps playing.

### Permissions

- Photo library
	- iOS: requests **add-only** only when `camera.saveToPhotos` is on
	* Android needs none (own `MediaStore` entries)
- Microphone: video mode only.
- Location: provided by the location domain (foreground).

### Seams

- consumes
	- `OverlayRendering`
	- `LocationProviding`
	- naming from `filename` domain
- publishes
	- usage-metrics (photo count)

## Settings

### General
| key                     | title            | control | default | gate |
| ----------------------- | ---------------- | ------- | ------- | ---- |
| `camera.shutterSound`   | Shutter sound    | toggle  | on      | free |
| `camera.orientationLock`| Orientation lock | toggle  | off     | free |

### Photo

| key                         | title                          | control | default | gate | requiresPermission   |
| --------------------------- | ------------------------------ | ------- | ------- | ---- | -------------------- |
| `camera.photo.resolution`   | Resolution                     | select  | max     | free | —                    |
| `camera.photo.format`       | Format                         | select  | JPG     | free | —                    |
| `camera.photo.saveOriginal` | Also save original             | toggle  | on      | free | —                    |
| `camera.saveToPhotos`       | Save to Camera Roll (iOS only) | toggle  | on      | free | add-only photo (iOS) |

- `camera.saveToPhotos` is iOS-only (hidden on Android). Revocation skips the
  Camera Roll copy (capture still succeeds app-private) and resumes on re-grant —
  per the permission-coupled policy in foundation.md.

### Video

| key | title | control | default | gate |
|---|---|---|---|---|
| `camera.video.resolution` | Resolution | select | max | free |
| `camera.video.fps` | FPS | select | 30 | free |

### EXIF

| key | title | control | default | gate | requiresPermission |
|---|---|---|---|---|---|
| `camera.exif.location` | Include EXIF location | toggle | on | free | location |

- `camera.exif.location` footnote: "Includes location data in the photo file."
  If location is denied/revoked, EXIF location is skipped and capture still
  succeeds — per the permission-coupled policy in foundation.md.

## Revision History

- 2026-07-01: Define `_original` suffix for saveOriginal copies.
- 2026-06-30: Initial camera spec.
