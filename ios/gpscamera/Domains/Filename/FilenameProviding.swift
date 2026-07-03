import Foundation

/// Names a captured file. Camera consumes this seam; it never builds names itself.
protocol FilenameProviding {
    /// Base name (no extension) for a capture at `date`, made unique via
    /// `isTaken` (auto-number on collision).
    nonisolated func makeName(for date: Date, isTaken: (String) -> Bool) -> String
}
