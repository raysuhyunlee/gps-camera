# Screenshot demo assets

Drop pre-arranged photos here for the screenshot demo mode (see
`spec/screenshots.md`). Files are bundled into the app (DEBUG builds) and read
by `ScreenshotDemo` / `ScreenshotSeed`.

- `scenes/screenshot-scene-<id>.jpg` - camera-feed backgrounds. Referenced by
  the UITest via `-Scene <id>`. Add a matching `LocationSnapshot` to the
  `scenes` table in `ScreenshotDemo.swift` so the overlay address/coordinates
  fit the photo.
- `gallery/screenshot-gallery-<n>.jpg` - captures for the gallery grid
  (`n` = 1, 2, 3, ...), ideally already showing the overlay.

Filenames must be unique and start with `screenshot-` (the app bundle flattens
resources, so names are looked up without their folder).
