# Camera

## Status

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

### Capture pipeline

1. Capture frame (photo) or stream (video).
2. If `overlay.enabled`, burn the rendered overlay layer (from `OverlayRendering`).
3. If `camera.exif.location`, write `LocationSnapshot` into EXIF.
4. Name the output via `filename`.
5. Save. If `camera.photo.saveOriginal`, also save the un-overlaid original.
6. Notify usage metrics (photo count) → `monetization` may present an interstitial.

### Seams

- consumes
	- `OverlayRendering`
	- `LocationProviding`
	- naming from `filename` domain
- publishes
	- usage-metrics (photo count)

## Settings

### General
| key                   | title         | control | default | gate |
| --------------------- | ------------- | ------- | ------- | ---- |
| `camera.shutterSound` | Shutter sound | toggle  | on      | free |

### Photo

| key                         | title              | control | default | gate |
| --------------------------- | ------------------ | ------- | ------- | ---- |
| `camera.photo.resolution`   | Resolution         | select  | max     | free |
| `camera.photo.format`       | Format             | select  | JPG     | free |
| `camera.photo.saveOriginal` | Also save original | toggle  | on      | free |

### Video

| key | title | control | default | gate |
|---|---|---|---|---|
| `camera.video.resolution` | Resolution | select | max | free |
| `camera.video.fps` | FPS | select | 30 | free |

### EXIF

| key | title | control | default | gate |
|---|---|---|---|---|
| `camera.exif.location` | Include EXIF location | toggle | on | free |

- `camera.exif.location` footnote: "Includes location data in the photo file."

## Revision History

- 2026-06-30: Initial camera spec.
