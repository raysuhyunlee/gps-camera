import Foundation

// TODO: minimal namer until the full filename domain lands (template, prefix,
// suffix, dateFormat, auto-number as pro settings — see filename.md).

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
