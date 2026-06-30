# Filename

## Status

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

## Revision History

- 2026-06-30: Initial filename spec.
