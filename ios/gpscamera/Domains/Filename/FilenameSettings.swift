//
//  FilenameSettings.swift
//  Filename - settings schema + typed read (filename.md "Settings"). All pro.
//

import Foundation

nonisolated enum FilenameSettingKey {
    static let template = "filename.template"
    static let prefix = "filename.prefix"
    static let suffix = "filename.suffix"
    static let dateFormat = "filename.dateFormat"
    static let autoNumber = "filename.autoNumber"
}

/// A template token, resolved per capture from `LocationSnapshot`
/// (filename.md "Template"). Raw values are the persisted orderList ids.
nonisolated enum FilenameToken: String, CaseIterable {
    case date, coordinates, address, altitude

    var titleKey: L10nKey {
        switch self {
        case .date: return "Date"
        case .coordinates: return "Coordinates"
        case .address: return "Address"
        case .altitude: return "Altitude"
        }
    }
}

nonisolated struct FilenameSettings {
    var template: [FilenameToken] = [.date]
    var prefix = "IMG_"
    var suffix = ""
    var dateFormat = "yyyyMMdd_HHmmss"
    var autoNumber = true

    init() {}

    init(from store: SettingsStore) {
        template = store.stringList(FilenameSettingKey.template)
            .compactMap(FilenameToken.init)
        prefix = store.string(FilenameSettingKey.prefix)
        suffix = store.string(FilenameSettingKey.suffix)
        dateFormat = store.string(FilenameSettingKey.dateFormat)
        autoNumber = store.bool(FilenameSettingKey.autoNumber)
    }
}

/// Filename section (filename.md "Settings"; placement from overview.md).
nonisolated struct FilenameSettingsProvider: SettingsProviding {
    var settingsSections: [SettingsSection] {
        [SettingsSection(id: "filename", titleKey: "Filename", items: [
            SettingItem(key: FilenameSettingKey.template, titleKey: "Template",
                        control: .orderList(FilenameToken.allCases.map {
                            OrderListOption(value: $0.rawValue, titleKey: $0.titleKey)
                        }),
                        defaultValue: .stringList([FilenameToken.date.rawValue]),
                        gate: .pro),
            SettingItem(key: FilenameSettingKey.prefix, titleKey: "Prefix",
                        control: .text, defaultValue: .string("IMG_"), gate: .pro),
            SettingItem(key: FilenameSettingKey.suffix, titleKey: "Suffix",
                        control: .text, defaultValue: .string(""), gate: .pro),
            SettingItem(key: FilenameSettingKey.dateFormat, titleKey: "Date format",
                        control: .select([
                            SelectOption(value: "yyyyMMdd_HHmmss",
                                         titleKey: "20260705_143501"),
                            SelectOption(value: "yyyy-MM-dd_HH-mm-ss",
                                         titleKey: "2026-07-05_14-35-01"),
                            SelectOption(value: "yyyyMMdd", titleKey: "20260705"),
                        ]),
                        defaultValue: .string("yyyyMMdd_HHmmss"), gate: .pro),
            SettingItem(key: FilenameSettingKey.autoNumber, titleKey: "Auto-number",
                        footnoteKey: "Adds a number automatically when a file of the same name exists.",
                        control: .toggle, defaultValue: .bool(true), gate: .pro),
        ])]
    }
}
