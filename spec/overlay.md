# Overlay

## Status

- 2026-07-05: Settings wired to the settings framework: enabled, item toggles,
  watermark (pro), style (font design, size, colors, opacity, coord format,
  unit — all pro). Dragged anchor persists via `overlay.layout`. Still
  deferred: preview + position-editor widgets in Settings (`Control.custom`),
  scale editing, `overlay.style.dateFormat` (per-locale default TBD).
- 2026-07-04: Items render as icon + label + value rows. Layer placement moved
  to the 9-anchor model: world-space anchor preserved across device rotation,
  changed by dragging the layer on Main (position editor v1). Scale editing +
  the Settings editor widget still deferred.
- 2026-07-04: iOS overlay v1 (`ios/gpscamera/Domains/Overlay`): text items
  (coordinates, altitude, accuracy, compass, time, address) + watermark; live
  layer on Main; rasterized layer burned into photos by camera. Settings
  hardcoded to defaults (`TODO: SettingsStore`). Deferred: map, QR, note,
  weather, logo items; styling UI; video burn (needs frame compositing).
- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**: the overlay layer
	- overlay items
	- drag positioning and scaling
	- styling
	- live preview
	- rendering onto media
	- Owns the shared position-editor widget
- **Non-interests**
	- data sourcing (location)
	- capture/burning mechanics (camera reuses the rendered layer)

## Details

### Items

* Each item is independently toggleable. 
* Source data comes from `LocationSnapshot` plus user input (note).
* Each item renders as an icon + value row; rows stack into one card
  (altitude + accuracy share a row; the accuracy value is tinted by level)

Supported items:
- map
- QR code 
- address 
* coordinates 
* altitude 
* location accuracy
* compass direction 
* capture time 
* note 
* weather (TODO)
* watermark
* logo / custom image (TODO) — user-supplied, distinct from the app watermark

### Position & scale editor

- The overlay card snaps to one of **9 anchors** (3x3: top/center/bottom x
  leading/center/trailing); default bottom-leading
- Anchors are **world-space**: preserved across device rotation — a top-left
  overlay stays at the world top-left in landscape (relocate + counter-rotate,
  animated, like camera's anchored controls)
- The user changes the anchor by dragging the layer on the Main screen; on
  release it snaps to the nearest anchor
- Burns place the layer at the same anchor on the upright capture
- TODO: scale editing; the `Control.custom` editor widget for Settings → Overlay

### Rendering

- `OverlayRendering` seam: given a `LocationSnapshot` + current overlay settings,
  produces the overlay layer.
- Reused three ways: live on Main, burned into captures by camera, and as the
  settings preview (a `Control.custom`).

### Styling

- font 
- font size 
- text color 
- background color 
- background opacity
- date/time format — defaults to the device locale's format; TODO: decide the
  per-locale default + user customization (`overlay.style.dateFormat`)
- coordinate format (lat-lon / DMS) 
- unit

## Settings

| key                         | title                               | control                  | default | gate                          |
| --------------------------- | ----------------------------------- | ------------------------ | ------- | ----------------------------- |
| `overlay.enabled`           | Include overlay in photo/video      | toggle                   | on      | free                          |
| `overlay.preview`           | Preview                             | custom                   | —       | free                          |
| `overlay.layout`            | Adjust position                     | custom (position editor) | —       | free                          |
| `overlay.item.*`            | Display items (one toggle per item) | toggle                   | on      | free                          |
| `overlay.item.watermark`    | Watermark                           | toggle                   | on      | **pro** (free cannot disable) |
| `overlay.style.font`        | Font                                | select                   | system  | **pro**                       |
| `overlay.style.size`        | Font size                           | stepper                  | default | **pro**                       |
| `overlay.style.textColor`   | Text color                          | color                    | —       | **pro**                       |
| `overlay.style.bgColor`     | Background color                    | color                    | —       | **pro**                       |
| `overlay.style.bgOpacity`   | Background opacity                  | slider                   | —       | **pro**                       |
| `overlay.style.dateFormat`  | Date/time format                    | select                   | —       | **pro**                       |
| `overlay.style.coordFormat` | Coordinate format                   | select (lat-lon / DMS)   | lat-lon | **pro**                       |
| `overlay.style.unit`        | Unit                                | select                   | metric  | **pro**                       |

## Implementation

### iOS

```
ios/gpscamera/Domains/Overlay/
├── OverlaySettings.swift  - setting keys, typed read from SettingsStore, SettingsProviding section
├── OverlayAnchor.swift    - 9-grid world-space anchor + orientation mapping
├── OverlayFormatter.swift - LocationSnapshot -> item strings (coord format, unit, heading, time)
├── OverlayLayer.swift     - SwiftUI layer: icon + label + value rows, watermark
├── OverlayLiveView.swift  - Main-screen host: anchored placement + drag-to-snap
├── OverlayRendering.swift - seam protocol, RenderedOverlay, placement metrics
└── OverlayRenderer.swift  - ImageRenderer-backed live + rasterized layer
ios/gpscameraTests/
└── OverlayValueTests.swift - formatter + anchor tests
```

Android: planned.

## Revision History

- 2026-07-05: Settings read from SettingsStore (items + style + persisted
  anchor); font design select added.
- 2026-07-04: Icon + label item rows; 9-anchor world-space placement with
  drag-to-snap (position editor v1).
- 2026-07-04: iOS overlay v1 — live layer on Main + photo burn, default settings.
- 2026-06-30: Initial overlay spec.
