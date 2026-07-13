//
//  DemoCaptureStore.swift
//  A `CaptureStoreBrowsing` over bundled demo photos, so the gallery grid + the
//  Main recent-thumbnail render for screenshots (screenshots.md) without a
//  Photos-library grant or any assets in the simulator's library.
//  DEBUG-only; compiles out of Release.
//

#if DEBUG
import UIKit

nonisolated struct DemoCaptureStore: CaptureStoreBrowsing {
    /// `screenshot-gallery-<n>.jpg` (n = 1, 2, ...), newest first.
    private var bundled: [(entry: CaptureEntry, url: URL)] {
        var items: [(CaptureEntry, URL)] = []
        var index = 1
        while let url = Bundle.main.url(forResource: "screenshot-gallery-\(index)",
                                        withExtension: "jpg") {
            let entry = CaptureEntry(id: "demo-\(index)",
                                     name: String(format: "DEMO_%03d", index),
                                     ext: "jpg",
                                     date: Date(timeIntervalSinceReferenceDate: Double(index)))
            items.append((entry, url))
            index += 1
        }
        return items.reversed()
    }

    func entries() async -> [CaptureEntry] { bundled.map(\.entry) }

    func thumbnail(for entry: CaptureEntry, maxPixel: CGFloat) async -> UIImage? {
        guard let url = bundledURL(for: entry) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func fileURL(for entry: CaptureEntry) async -> URL? { bundledURL(for: entry) }

    func delete(_ entries: [CaptureEntry]) async -> Bool { false }

    private func bundledURL(for entry: CaptureEntry) -> URL? {
        bundled.first { $0.entry.id == entry.id }?.url
    }
}
#endif
