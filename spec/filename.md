# Filename

## Status

- 2026-07-03: Minimal `DefaultFilenameProvider` seam
  (`ios/gpscamera/Domains/Filename`) so camera can name outputs
  (`IMG_<timestamp>` + auto-number). Template/prefix/suffix/dateFormat settings
  pending.
- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**"
	- naming captured files from a template
- **Non-interests**
	- data sourcing
	- saving mechanics

## Details

### Template

- An ordered list of tokens
	- User can reorder the tokens by drag-and-drop (`Control.orderList`).
- Tokens draw from the same fields overlay items use (date, coordinates,
  address, altitude, …), resolved per capture from `LocationSnapshot`.

### Composition

- Final name = `prefix` + rendered template + `suffix`, with `dateFormat`
  applied to date tokens.
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
├── FilenameProviding.swift       - seam protocol
└── DefaultFilenameProvider.swift - IMG_<timestamp> + auto-number
ios/gpscameraTests/
└── FilenameValueTests.swift      - filename value-type tests
```

- Stub for now: only `IMG_<timestamp>` + auto-number. Template/prefix/suffix/
  dateFormat land with the settings framework.

Android: planned.

## Revision History

- 2026-07-03: Minimal `DefaultFilenameProvider` seam (camera consumer).
- 2026-06-30: Initial filename spec.
