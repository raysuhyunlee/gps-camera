//
//  ScreenshotSeed.swift
//  Populates the app-private capture store with bundled demo photos so the
//  gallery grid + Main recent-thumbnail render for screenshots (screenshots.md).
//  Files land in the same `Captures/` dir `CaptureStore` enumerates, so no
//  gallery-domain change is needed. DEBUG-only; compiles out of Release.
//

#if DEBUG
import UIKit

enum ScreenshotSeed {
    /// Copies `screenshot-gallery-<n>.jpg` (n = 1, 2, ...) into the capture
    /// store, oldest-first so `mediaURLs()` (newest-first) lists them in order.
    /// Clears any prior seed so re-runs are deterministic.
    static func seedCaptures() {
        let store = CaptureStore()
        let existing = (try? FileManager.default.contentsOfDirectory(
            at: store.directory, includingPropertiesForKeys: nil)) ?? []
        existing.forEach { try? FileManager.default.removeItem(at: $0) }

        var index = 1
        while let url = Bundle.main.url(forResource: "screenshot-gallery-\(index)",
                                        withExtension: "jpg"),
              let image = UIImage(contentsOfFile: url.path),
              let data = image.jpegData(compressionQuality: 0.95) {
            _ = try? store.write(data, name: String(format: "DEMO_%03d", index), ext: "jpg")
            index += 1
        }
    }
}
#endif
