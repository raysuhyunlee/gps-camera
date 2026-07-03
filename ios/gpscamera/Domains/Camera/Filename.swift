import Foundation

// TODO: filename domain — this is a minimal seam + default namer so camera can
// name outputs today. When the `filename` domain lands (template, prefix,
// suffix, dateFormat, auto-number as pro settings), move this to
// `Domains/Filename/` and replace `DefaultFilenameProvider` with the real one.

/// Names a captured file. Camera consumes this seam; it never builds names itself.
protocol FilenameProviding {
    /// Base name (no extension) for a capture at `date`, made unique via
    /// `isTaken` (auto-number on collision).
    nonisolated func makeName(for date: Date, isTaken: (String) -> Bool) -> String
}

/// `IMG_<yyyyMMdd_HHmmss>`, auto-numbered on collision (`_1`, `_2`, ...).
nonisolated struct DefaultFilenameProvider: FilenameProviding {
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f
    }()

    func makeName(for date: Date, isTaken: (String) -> Bool) -> String {
        let base = "IMG_\(formatter.string(from: date))"
        if !isTaken(base) { return base }
        var n = 1
        while isTaken("\(base)_\(n)") { n += 1 }
        return "\(base)_\(n)"
    }
}
