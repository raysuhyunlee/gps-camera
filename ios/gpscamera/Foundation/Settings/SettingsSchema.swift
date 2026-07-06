//
//  SettingsSchema.swift
//  Foundation - settings framework (foundation.md "Settings Framework").
//  Generic and domain-agnostic; domains describe their sections with these types.
//

import Foundation
import SwiftUI

// TODO: L10n framework - keys render as raw English until it lands.
typealias L10nKey = String

nonisolated enum SettingGate { case free, pro }

/// OS permission a setting depends on (foundation.md "Permission-coupled settings").
nonisolated enum SettingPermission { case location, photoAddOnly }

nonisolated struct SelectOption: Identifiable {
    let value: String
    let titleKey: L10nKey
    /// Renders the option label in this font (e.g. a font picker previews
    /// each choice in its own typeface). Selects with any previewed option
    /// use the navigation-link style: menus strip custom fonts.
    var previewFont: Font? = nil
    var id: String { value }
}

/// A labeled entry of an orderList control. The framework treats ids as opaque.
nonisolated struct OrderListOption: Identifiable {
    let value: String
    let titleKey: L10nKey
    var id: String { value }
}

nonisolated enum Control {
    case toggle
    case select([SelectOption])
    case stepper(range: ClosedRange<Double>, step: Double)
    case slider(range: ClosedRange<Double>)
    case color
    case text
    /// Ordered include-list: drag to reorder, tap to include/exclude.
    /// Value is the ordered list of included ids.
    case orderList([OrderListOption])
    case navigation(sectionRef: String)
    case action(actionRef: String)
    /// Domain-supplied row view (e.g. the pro banner) - keeps foundation generic.
    case custom(view: @MainActor () -> AnyView)
}

nonisolated struct SettingItem: Identifiable {
    let key: String                  // stable, namespaced, e.g. "camera.photo.format"
    let titleKey: L10nKey
    var footnoteKey: L10nKey? = nil
    let control: Control
    var defaultValue: SettingValue? = nil   // nil for navigation/action/custom
    var gate: SettingGate = .free
    var visibleWhen: ((SettingsStore) -> Bool)? = nil
    /// False -> the row renders greyed-out and inert (e.g. a master switch is
    /// off). Unlike `visibleWhen`, the row stays visible.
    var enabledWhen: ((SettingsStore) -> Bool)? = nil
    var requiresPermission: SettingPermission? = nil

    var id: String { key }
}

nonisolated struct SettingsSection: Identifiable {
    let id: String
    let titleKey: L10nKey
    var order = 0                    // assigned by the composition root
    let items: [SettingItem]
}

/// The seam each domain conforms to.
protocol SettingsProviding {
    nonisolated var settingsSections: [SettingsSection] { get }
}
