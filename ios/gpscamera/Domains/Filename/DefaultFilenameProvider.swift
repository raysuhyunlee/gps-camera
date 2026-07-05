import Foundation

/// Renders `prefix + template tokens + suffix` (filename.md "Composition"),
/// tokens resolved from the capture-time `LocationSnapshot`. Auto-numbers on
/// collision (`_1`, `_2`, ...) when `filename.autoNumber` is on.
nonisolated struct DefaultFilenameProvider: FilenameProviding {
    private let settings: () -> FilenameSettings

    /// Live settings (read per capture, so edits apply immediately).
    init(store: SettingsStore) {
        settings = { FilenameSettings(from: store) }
    }

    /// Fixed settings - defaults for previews/tests.
    init(fixed: FilenameSettings = FilenameSettings()) {
        settings = { fixed }
    }

    func makeName(for date: Date, snapshot: LocationSnapshot?,
                  isTaken: (String) -> Bool) -> String {
        let s = settings()
        let parts = s.template.compactMap { render($0, date: date, snapshot: snapshot,
                                                   dateFormat: s.dateFormat) }
        var base = sanitize(s.prefix + parts.joined(separator: "_") + s.suffix)
        if base.isEmpty { base = "IMG" }
        guard s.autoNumber, isTaken(base) else { return base }
        var n = 1
        while isTaken("\(base)_\(n)") { n += 1 }
        return "\(base)_\(n)"
    }

    /// nil when the token's data is unavailable (no fix, no address) - the
    /// token is skipped rather than rendering a placeholder.
    private func render(_ token: FilenameToken, date: Date,
                        snapshot: LocationSnapshot?, dateFormat: String) -> String? {
        switch token {
        case .date:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = dateFormat
            return formatter.string(from: date)
        case .coordinates:
            guard let c = snapshot?.coordinate else { return nil }
            return String(format: "%.6f_%.6f", c.latitude, c.longitude)
        case .address:
            return snapshot?.address
        case .altitude:
            guard let altitude = snapshot?.altitude else { return nil }
            return String(format: "%.0fm", altitude)
        }
    }

    /// Strip path-hostile characters from user text + addresses.
    private func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: "[/:\\\\]", with: "-", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
