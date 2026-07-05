# Filename

## Status

- 2026-07-05: Templating implemented: token orderList (date, coordinates,
  address, altitude) + prefix/suffix/dateFormat/autoNumber, all read from
  SettingsStore per capture. Defaults reproduce the old stub
  (`IMG_` + `yyyyMMdd_HHmmss`).
- 2026-07-03: Minimal `DefaultFilenameProvider` seam
  (`ios/gpscamera/Domains/Filename`) so camera can name outputs.
- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**"
	- naming captured files from a template
- **Non-interests**
	- data sourcing
	- saving mechanics

## Details

### Template

- An ordered list of tokens (`Control.orderList`)
	- User reorders by drag-and-drop and includes/excludes tokens.
- Tokens draw from the same fields overlay items use (date, coordinates,
  address, altitude, …), resolved per capture from `LocationSnapshot`.
- A token whose data is unavailable (no fix, no address) is skipped.

### Composition

- Final name = `prefix` + rendered template (tokens joined by `_`) + `suffix`,
  with `dateFormat` applied to date tokens.
- Path-hostile characters (`/`, `:`, `\`) are replaced with `-`; an empty
  result falls back to `IMG`.
- **Auto-number**: on a name collision, append an incrementing number.

### Seam

- Consumes
	- `LocationProviding`'s snapshot at capture time
- Publishes
	- the name of the file

## Settings

| key                   | title       | control   | default | gate |
| --------------------- | ----------- | --------- | ------- | ---- |
| `filename.template`   | Template    | orderList | —       | pro  |
| `filename.prefix`     | Prefix      | text      | —       | pro  |
| `filename.suffix`     | Suffix      | text      | —       | pro  |
| `filename.dateFormat` | Date format | select    | —       | pro  |
| `filename.autoNumber` | Auto-number | toggle    | on      | pro  |

- `filename.autoNumber` footnote: "Adds a number automatically when a file of the
  same name exists."

## Implementation

### iOS

```
ios/gpscamera/Domains/Filename/
├── FilenameProviding.swift       - seam protocol (date + snapshot -> unique name)
├── FilenameSettings.swift        - setting keys, tokens, typed read, SettingsProviding section
└── DefaultFilenameProvider.swift - template renderer + sanitize + auto-number
ios/gpscameraTests/
└── FilenameValueTests.swift      - template/composition/auto-number tests
```

Android: planned.

## Revision History

- 2026-07-05: Template tokens + prefix/suffix/dateFormat/autoNumber from
  SettingsStore; seam gains the capture snapshot.
- 2026-07-03: Minimal `DefaultFilenameProvider` seam (camera consumer).
- 2026-06-30: Initial filename spec.
