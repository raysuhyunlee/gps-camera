//
//  SettingsRegistry.swift
//  Foundation - collects SettingsProviding domains (explicitly injected by the
//  composition root), sorts top-level sections by order, resolves navigation.
//

import Foundation
import SwiftUI

nonisolated final class SettingsRegistry {
    /// Top-level sections, sorted by the root-assigned order.
    let topLevel: [SettingsSection]
    private let byID: [String: SettingsSection]

    /// `order`: composition-root section placement (overview.md). Sections
    /// absent from the map are sub-sections, reached via `Control.navigation`.
    init(providers: [SettingsProviding], order: [String: Int], store: SettingsStore) {
        let all = providers.flatMap(\.settingsSections)
        byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        topLevel = all
            .compactMap { section in
                order[section.id].map { var s = section; s.order = $0; return s }
            }
            .sorted { $0.order < $1.order }

        var defaults: [String: SettingValue] = [:]
        for item in all.flatMap(\.items) {
            if let value = item.defaultValue { defaults[item.key] = value }
        }
        store.register(defaults)
    }

    func section(_ id: String) -> SettingsSection? { byID[id] }

    /// Navigation path (section ids, root first) to the section whose items
    /// contain `key` - for deep-linking a SettingItem (foundation.md).
    func path(to key: String) -> [String] {
        for root in topLevel {
            if let path = find(key, in: root) { return path }
        }
        return []
    }

    private func find(_ key: String, in section: SettingsSection) -> [String]? {
        if section.items.contains(where: { $0.key == key }) { return [section.id] }
        for item in section.items {
            if case .navigation(let ref) = item.control, let sub = byID[ref],
               let path = find(key, in: sub) {
                return [section.id] + path
            }
        }
        return nil
    }
}
