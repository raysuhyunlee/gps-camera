//
//  SettingValue.swift
//  Foundation - settings framework (foundation.md "Settings Framework")
//

import Foundation

/// A setting's value. Persisted as the matching primitive in UserDefaults;
/// the registered default decides which case a key reads back as.
nonisolated enum SettingValue: Equatable {
    case bool(Bool)
    case string(String)     // select value, text, color hex
    case number(Double)     // stepper, slider
    case stringList([String])  // orderList (ordered enabled ids)

    var boolValue: Bool { if case .bool(let v) = self { return v }; return false }
    var stringValue: String { if case .string(let v) = self { return v }; return "" }
    var numberValue: Double { if case .number(let v) = self { return v }; return 0 }
    var stringListValue: [String] { if case .stringList(let v) = self { return v }; return [] }

    /// The primitive stored in UserDefaults.
    var primitive: Any {
        switch self {
        case .bool(let v): return v
        case .string(let v): return v
        case .number(let v): return v
        case .stringList(let v): return v
        }
    }

    /// Read a primitive back as the same case as `default`.
    static func from(_ primitive: Any?, like def: SettingValue) -> SettingValue? {
        switch def {
        case .bool: return (primitive as? Bool).map(SettingValue.bool)
        case .string: return (primitive as? String).map(SettingValue.string)
        case .number: return (primitive as? Double).map(SettingValue.number)
        case .stringList: return (primitive as? [String]).map(SettingValue.stringList)
        }
    }
}
