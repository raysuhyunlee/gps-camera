# Foundation

## Status

- 2026-06-30: Initial spec.

## Domain Definition

- **Interests**
	- cross-cutting infrastructure every domain depends on
- **Non-interests**
	- any feature logic
	- Foundation is generic and domain-agnostic; it SHOULD NEVER import a domain.

## Details

### L10n

- Every user-facing string resolves through an `L10nKey`.
- Language is selectable in Settings → General
	- defaults to the system locale.

### Theme

- Follows the app's base theme (system light/dark)
- No in-app override

### Design System

- Shared visual tokens (color, spacing, type scale).
- The generic settings-control widgets (toggle, select, stepper, slider, color,
  text, orderList)
	- follows the native ui elements by default

### Settings Framework

The Settings screen renders registered sections generically and knows no domain.

Language-neutral schema (each platform mirrors it in its own types).

**Control** — one of:

| Control | Use |
|---|---|
| `toggle` | booleans |
| `select(options)` | resolution, format, fps, font, formats, unit |
| `stepper(range, step)` | font size |
| `slider(range)` | opacity |
| `color` | text / background color |
| `text` | prefix, suffix, note |
| `orderList` | drag-reorder of opaque labeled items |
| `navigation(sectionRef)` | push a sub-section |
| `action(actionRef)` | restore purchase, send feedback |
| `custom(controlRef)` | domain-supplied view (overlay preview, position editor) — keeps foundation generic |

**SettingItem** — `key` (stable, namespaced, e.g. `camera.photo.format`),
`titleKey` (l10n), `footnoteKey?` (l10n), `control`, `defaultValue`,
`gate` (`free` | `pro`), `visibleWhen?` (predicate over another setting's value).

**SettingsSection** — `id`, `titleKey` (l10n), `order` (assigned by the
composition root, see overview.md), `items` (list of `SettingItem`).

**SettingsProviding** — the seam each domain conforms to: exposes its
`settingsSections`.

- `SettingsRegistry` collects all `SettingsProviding` domains (explicitly
  injected by the composition root, not auto-discovered), sorts sections by
  `order`, renders each `Control` generically.
- `SettingsStore` contain typed settings for each domain
- **Gating**: a `.pro` item shows a lock for `.free` users and routes to the
  paywall on tap (entitlement from `monetization`).
- **`custom` controls**: the providing domain supplies the view and binds it to
  its own `key`

### Usage Metrics

- A lightweight bus publishing session-scoped counters (e.g. photo count,
  session count).
- Consumed by `monetization` for ad triggers and nudge rules. Resets per session.

### Version
- a source-of-truth for the current app version

### Misc

- **Feedback** - Settings → Control.action
	- TBD
- **ToS, Legal** - Settings → Control.action
	- tos: www.raysuhyunlee.com/gpscamera/tos
	- legal: www.raysuhyunlee.com/gpscamera/legal

## Revision History

- 2026-06-30: Initial foundation spec
