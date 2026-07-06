# Camera

## Status

- 2026-07-05: Gallery wired: Main hosts the recent-thumbnail control
  (`GalleryProviding`); the capture store publishes `CaptureStoreBrowsing`
  (list newest-first, delete) and posts `captureStoreDidChange` on write/delete.
- 2026-07-05: Capture settings wired to the settings framework (no more
  hardcoded defaults): shutter sound, orientation lock, photo resolution +
  format (JPG/HEIC), save original, save to Camera Roll, video resolution +
  fps, EXIF location. Settings gear added to the top-right control group;
  permission mismatch popup surfaces on Main. Still TODO: usage-metrics
  publish (monetization), JP/KR shutter-sound warning.
- 2026-07-04: Photo pipeline steps 2 (overlay burn) + 5 (`_original` copy)
  wired to the overlay domain; Main screen hosts the live overlay layer.
  Video burn deferred (frame compositing).
- 2026-07-04: Camera view UI clarified + iOS aligned - top/bottom control
  sections, GPS icon + tooltip, rotatable vs fixed controls (animated). Photo
  gallery is a placeholder until the `gallery` domain lands.
- 2026-07-04: iOS video mode + audio and orientation lock implemented.
  Capture settings still hardcoded to defaults (`TODO: SettingsStore`). Deferred:
  settings-framework wiring, usage-metrics publish (monetization).
- 2026-07-03: iOS Main screen + photo pipeline implemented
  (`ios/gpscamera/Domains/Camera`).
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
- GPS accuracy indicator - from `location` (`accuracyLevel`)
- Live overlay - from `overlay`
- Pro banner - from `monetization`
- Recent-capture thumbnail - from `gallery` (opens the gallery)

### Controls

Three control types:

- **Rotatable** - square (1:1); rotate in place to match device orientation with
  an animated transition; freeze when `camera.orientationLock` is on, and while
  recording (stay at the orientation recording started with). Members: GPS
  status, flash, settings gear (and future top-right controls), lens switch,
  photo gallery, front/back switch.
- **Fixed** - never rotate. Members: shutter, photo/video switch.
- **Anchored** - keep a world-space anchor (e.g. top-middle): relocate to the
  screen edge matching the device orientation and rotate upright, animated.
  Freeze like rotatable controls (recording, `camera.orientationLock`).
  Members: recording time.

Individual controls:

- GPS status - icon only, tinted by accuracy (green good / yellow normal /
  red bad); tap shows a status tooltip (good / normal / bad). From `location`
  `accuracyLevel`.
- Photo/video switch
- Lens / field-of-view switch (ultra-wide / wide / tele, as available)
- Flash toggle
- Front/back switch
- Photo gallery - recent-capture thumbnail; opens the gallery (`gallery` domain)
- Shutter
- Settings gear - opens the Settings screen (sheet)

### Layout

Portrait orientation. Two **control sections**, top and bottom, each a
semi-transparent black bar so the preview shows through behind.

- Top section
	- GPS status - top left
	- Other controls (flash, settings gear) - top right; grouped, but each
	  rotates individually
- Bottom section
	- Photo gallery - bottom left
	- Shutter - center
	- Front/back switch - bottom right
	- Photo/video switch - below the shutter
- Lens selector - floats above the shutter, above (outside) the bottom section,
  over the preview
- Recording time - anchored at the world-space top-middle (portrait: inside the
  top section; landscape: middle of the corresponding screen edge)

### Device Orientation

- The interface is fixed in portrait; sections and fixed controls keep their
  positions
- Rotatable controls rotate in place to match device orientation (animated
  transition); the live overlay keeps its world-space anchor (overlay domain)
- While recording, all control rotation and the capture rotation freeze at the
  orientation recording started with
- When `camera.orientationLock` is on, rotation freezes at the current
  orientation (capture proceeds in the locked orientation)
- Orientation changes never mutate the live capture graph; capture rotation is
  applied at shutter / record start (mutating running connections flickers the
  preview)

### Preview Transitions

- Lens / facing / photo-video switches freeze the last preview frame under a
  blur until the new session graph is ready, then fade to live - the feed never
  flickers to black (like the native camera app)

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
- `camera.shutterSound` gates capture sounds: the photo shutter and the video
  record start/stop sounds (system sounds, like the native camera).
	- Photo shutter suppression is best-effort: some regions (e.g. JP/KR)
	  force the sound at the OS level.
	- TODO) Display a warning message under shutter sound setting item when the setting is off in this regions.

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
	- `EntitlementProviding` (pro gating for the settings sheet)
	- `PaywallProviding` (locked pro rows open the paywall sheet)
	- `ProBannerProviding` (thin pro banner hosted under the top controls)
	- `GalleryProviding` (recent-thumbnail control hosted on Main)
- publishes
	- `CaptureStoreBrowsing` (gallery reads + deletes store entries)
	- usage-metrics (photo count)

## Settings

### General
| key                     | title                 | control | default | gate | requiresPermission |
| ----------------------- | --------------------- | ------- | ------- | ---- | ------------------ |
| `camera.shutterSound`   | Shutter sound         | toggle  | on      | free | -                  |
| `camera.orientationLock`| Orientation lock      | toggle  | off     | free | -                  |
| `camera.exif.location`  | Include EXIF location | toggle  | on      | free | location           |

- `camera.exif.location` sits at the top level of the Capture section (not in a
  sub-section). Footnote: "Includes location data in the photo file." If
  location is denied/revoked, EXIF location is skipped and capture still
  succeeds - per the permission-coupled policy in foundation.md.

### Photo

| key                         | title                          | control | default | gate | requiresPermission   |
| --------------------------- | ------------------------------ | ------- | ------- | ---- | -------------------- |
| `camera.photo.resolution`   | Resolution                     | select  | highest | free | -                    |
| `camera.photo.format`       | Format                         | select  | JPG     | free | -                    |
| `camera.photo.saveOriginal` | Also save original             | toggle  | on      | free | -                    |
| `camera.saveToPhotos`       | Save to Camera Roll (iOS only) | toggle  | on      | free | add-only photo (iOS) |

- `camera.saveToPhotos` is iOS-only (hidden on Android). Revocation skips the
  Camera Roll copy (capture still succeeds app-private) and resumes on re-grant -
  per the permission-coupled policy in foundation.md.

### Video

| key | title | control | default | gate |
|---|---|---|---|---|
| `camera.video.resolution` | Resolution | select | highest | free |
| `camera.video.fps` | FPS | select | 30 | free |

- Resolution options are concrete values read from the hardware (back wide
  camera), never a literal "max": photo lists its 4:3 sizes as "N MP (WxH)",
  video lists 4K/1080p/720p as supported. Default = highest available. At
  capture, the session clamps to what the active format supports.

## Implementation

### iOS

```
ios/gpscamera/Domains/Camera/
├── CameraSettings.swift          - setting keys, typed read, CaptureQuality, SettingsProviding sections
├── CameraView.swift              - Main screen: preview, GPS indicator, photo/video controls, settings sheet + mismatch popup
├── CameraController.swift        - ObservableObject; session + permissions + shutter/record
├── CameraSession.swift           - AVCaptureSession wrapper (facing, lens, flash, mode, photo + movie + frame output)
├── CameraPreview.swift           - AVCaptureVideoPreviewLayer host + freeze-blur transition
├── CameraOrientation.swift       - device orientation -> control angle, capture rotation, anchor alignment
├── CameraAuthorization.swift     - camera permission -> PermissionStatus
├── MicrophoneAuthorization.swift - mic permission -> PermissionStatus (video only)
├── CaptureStoreBrowsing.swift    - seam consumed by gallery: browse/delete + change notification
├── PhotoCaptureService.swift     - photo pipeline + CaptureStore + CameraRoll (add-only copy)
├── VideoCaptureService.swift     - video pipeline (movie output, ISO6709 GPS metadata)
└── GPSMetadata.swift             - LocationSnapshot -> EXIF GPS dictionary
ios/gpscameraTests/
└── CameraValueTests.swift        - camera value-type tests
```

Android: planned.

## Revision History

- 2026-07-06: Debug surface backdoor moved off the GPS icon to the Settings
  title (7 rapid taps; see foundation.md "Settings Framework").
- 2026-07-06: Debug surface gains a pro status section (entitlement + refresh
  via `ProStore.refresh()`).
- 2026-07-06: Pro banner hosted under the top controls (`ProBannerProviding`;
  disabled while recording).
- 2026-07-06: Locked pro settings rows route to the paywall
  (`PaywallProviding` sheet over the settings sheet).
- 2026-07-05: Gallery button replaces the placeholder (hosted `GalleryProviding`
  control); `CaptureStoreBrowsing` seam + `captureStoreDidChange` notification.
- 2026-07-05: CameraView consumes `EntitlementProviding` directly (no closure
  default); dev backdoor to the location debug surface (long-press GPS icon).
- 2026-07-05: EXIF location toggle moved to the top level of the Capture
  section (EXIF sub-section removed).
- 2026-07-05: Resolution selects list concrete hardware values; default is the
  highest available.
- 2026-07-05: Wire all capture settings to the settings framework; add the
  settings gear + mismatch popup to Main; HEIC format + resolution/fps applied
  to the session.
- 2026-07-04: Burn the overlay layer into photos + save the `_original` copy;
  host the live overlay on Main (overlay v1). Video burn deferred.
- 2026-07-04: Add anchored control type (recording time), freeze rotatables
  while recording, freeze-blur preview transition on switches.
- 2026-07-04: Clarify camera view UI (rotatable vs fixed controls, top/bottom
  control sections, layout) + align iOS CameraView.
- 2026-07-04: iOS video mode (movie output, lazy mic permission, ISO6709 GPS
  metadata, PHOTO/VIDEO switch) + orientation lock (capture-rotation on the
  output connections).
- 2026-07-03: iOS Main screen (preview, GPS indicator, lens/flash/front-back
  controls) + photo capture pipeline (EXIF GPS, app-private store, Camera Roll
  add-only copy).
- 2026-07-01: Define `_original` suffix for saveOriginal copies.
- 2026-06-30: Initial camera spec.
