# Foundation

## Status

- 2026-07-05: iOS settings framework implemented (`Foundation/Settings`):
  schema, thread-safe `SettingsStore` over UserDefaults, registry, generic
  `SettingsScreen` renderer, permission-coupled toggles + mismatch popup +
  deep-link highlight. Camera/overlay/filename sections wired. Deferred:
  l10n (titles are raw English), General/Language + feedback/about sections,
  `custom` control views, `action` handlers.
- 2026-07-01: iOS `PermissionStatus` added (`ios/gpscamera/Foundation`).
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
- Bundled fonts: `Resources/Fonts` ships OFL-licensed families (+ license
  texts); `BundledFonts.registerAll()` registers them at startup (runtime
  CoreText registration, no Info.plist). Domains reference families by name.

### Settings Framework

The Settings screen renders registered sections generically and knows no domain.

```
Control = one of:
    toggle                  // booleans
    select(options)         // resolution, format, fps, font, formats, unit;
                            //   an option may carry a preview font (font picker
                            //   rows render in their own typeface)
    stepper(range, step)    // font size
    slider(range)           // opacity
    color                   // text / background color
    text                    // prefix, suffix, note
    orderList               // ordered include-list of opaque labeled items:
                            //   drag to reorder, include/exclude entries;
                            //   value = ordered ids of included items
    navigation(sectionRef)  // push a sub-section
    action(actionRef)       // restore purchase, send feedback
    custom(controlRef)      // domain-supplied view (overlay preview, position
                            //   editor) — keeps foundation generic

SettingItem {
    key                  // stable, namespaced, e.g. "camera.photo.format"
    titleKey             // l10n
    footnoteKey?         // l10n
    control              // one of Control (above)
    defaultValue
    gate                 // free | pro
    visibleWhen?         // predicate over another setting's value; hides the row
    enabledWhen?         // predicate; false greys the row out but keeps it
                         //   visible (e.g. a master switch is off)
    requiresPermission?  // OS permission the item depends on (add-only photo, location, …)
}

SettingsSection {
    id
    titleKey             // l10n
    order                // assigned by the composition root (see overview.md)
    items                // list of SettingItem
}

SettingsProviding {      // the seam each domain conforms to
    settingsSections     // -> list of SettingsSection
}
```

- `SettingsRegistry` collects all `SettingsProviding` domains (explicitly
  injected by the composition root, not auto-discovered), sorts sections by
  `order`, renders each `Control` generically.
- `SettingsStore` contain typed settings for each domain
- **Gating**: a `.pro` item shows a lock for `.free` users and routes to the
  paywall on tap (entitlement from `monetization`).
- **`custom` controls**: the providing domain supplies the view and binds it to
  its own `key`

#### UI interests vs config interests

The schema carries **semantic config only**: keys, defaults, control kind +
option values, gating, dependencies, permissions. Everything about how that
config *looks or feels* belongs elsewhere:

- **Renderer policy** (SettingsView): look-and-feel that applies uniformly —
  keyboard submit key on text items, picker style choice, highlight timing.
  Never a schema field; changing it touches only the renderer.
- **Composition root** (overview.md): placement — section order.
- **Presentation hints** (schema, exception): per-item look data only the
  domain can supply (e.g. a font option previews in its own typeface). Optional
  fields, named as presentation (`previewFont`), read by nothing but the
  renderer.

New need? Prefer renderer policy; add a hint field only when the renderer
cannot know it.

#### Permission-coupled settings

- `PermissionStatus` is the shared authorization enum for every OS permission
  (location, camera, photos, ...): `notDetermined` / `denied` / `authorized`.
  Each provider collapses platform-specific statuses into these.

An item with `requiresPermission` checks the permission every time it is read.
* on && granted -> effective
* on && !granted -> mismatch popup

Acquiring permission
* enabling the item requests the permission if not granted yet
* if the user denies, the item goes back into disabled state

Mismatch Popup
* if the item is enabled, it checks the permission every time it's read
* when the permission is denied (e.g., revoked by the user), it shows a mismatch popup
* show popup the first time the mismatch is detected
* non-blocking (the action still proceeds with the feature skipped)
* popup dialog has two buttons
	* Close - dismiss
	* Go to Settings - navigate to the Settings page holding the item and highlight that row
* The framework should support deep-linking to a `SettingItem` by `key` and transiently
highlighting it

Note: Mismatch popup only shows when the user had granted the permission and revoked at some point. When the user denies the permission right when he toggles the item, the item will be disabled immediately and the popup will not be shown.

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

## Implementation

### iOS

```
ios/gpscamera/Foundation/
├── PermissionStatus.swift - shared authorization enum
├── BundledFonts.swift     - runtime registration of Resources/Fonts
└── Settings/
    ├── SettingsSchema.swift      - Control, SettingItem, SettingsSection, SettingsProviding
    ├── SettingValue.swift        - typed value (bool/string/number/stringList) <-> UserDefaults
    ├── SettingsStore.swift       - thread-safe store; permission-coupled effective reads + mismatch notification
    ├── SettingsRegistry.swift    - collects providers, root-assigned ordering, deep-link paths
    ├── SettingsPermissions.swift - SettingPermission status/request (location, add-only photos)
    ├── SettingsView.swift        - generic SettingsScreen renderer (controls, pro lock, highlight)
    └── ColorHex.swift            - Color <-> #RRGGBBAA for Control.color
```

Android: planned.

## Revision History

- 2026-07-05: UI-vs-config boundary documented (renderer policy / root
  placement / presentation hints); text items submit with a Done key.
- 2026-07-05: Bundled-font registration (`BundledFonts`) for the OFL fonts
  under `Resources/Fonts`.
- 2026-07-05: `enabledWhen` added to `SettingItem` (grey-out under a master
  switch). orderList editor: section-scoped row identity (fixes ghost rows).
- 2026-07-05: iOS settings framework (schema, store, registry, renderer,
  permission coupling). orderList clarified: reorder + include/exclude.
- 2026-06-30: Initial foundation spec
