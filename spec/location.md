# Location

## Status

- 2026-07-01: iOS module implemented (`ios/gpscamera/Domains/Location`).
- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**: GPS + sensor data as a pure provider. Publishes a single
  `LocationSnapshot` consumed by overlay, camera (EXIF), and filename.
- **Non-interests**: rendering (overlay), EXIF writing (camera), naming
  (filename), persistence, formatting. Formats (coord style, unit) belong to the
  consumer that displays them (overlay).

## Details

### LocationSnapshot

* Published model (immutable)
* Refreshed as sensors update.

| Field            | Notes                                                                                                                        |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `coordinate`     | latitude / longitude                                                                                                         |
| `altitude`       | meters                                                                                                                       |
| `accuracyMeters` | horizontal accuracy radius, meters                                                                                           |
| `accuracyLevel`  | `.good` / `.normal` / `.bad`, classified from `accuracyMeters`<br>- `.good` < 10m<br>- `.normal` < 30m<br>- `.bad` otherwise |
| `heading`        | compass degrees + cardinal                                                                                                   |
| `timestamp`      | capture time                                                                                                                 |
| `weather`        | TODO (temp, pressure, wind, humidity)                                                                                        |
| `address`        | reverse-geocoded in the app language (`preferredLocale`, bound by the root to foundation `L10n.locale`; re-geocodes on change) |

### Accuracy classification

- Thresholds map `accuracyMeters` → `.good` / `.normal` / `.bad`.
- Surfaced as the Main-screen GPS indicator (rendered by the camera surface).

### Compass

- Heading in degrees plus cardinal direction (N/NE/E/…)
- Should give correct direction depending on the current device orientation (portrait, landscape)

### Weather (TODO)

- Fetched from a weather provider keyed by `coordinate`.
- Fields: temperature, pressure, wind speed, humidity.

### Seam

Publishes:
- `LocationProviding` - the latest `LocationSnapshot` 

### Permissions

- Foreground (while-using-the-app) location permission.

## Settings

* None. Location has no user-facing settings - it is a pure data provider. 
* Coordinate format and unit are overlay style settings

## Implementation

### iOS

```
ios/gpscamera/Domains/Location/
├── LocationSnapshot.swift  - published model + value types (Coordinate, Heading, AccuracyLevel, Cardinal)
├── LocationProviding.swift - seam protocol
└── LocationProvider.swift  - CoreLocation-backed provider (GPS, heading, reverse geocode)
ios/gpscameraTests/
└── LocationValueTests.swift - location value-type tests
```

Android: planned.

## Revision History

- 2026-07-12: Addresses geocode in the app language (`preferredLocale` bound to
  `L10n.locale`); `refreshAddress()` re-geocodes when it changes.
- 2026-06-30: Initial location spec.
