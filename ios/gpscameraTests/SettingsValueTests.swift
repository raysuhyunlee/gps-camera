//
//  SettingsValueTests.swift
//  Settings framework value logic: store defaults + persistence, registry
//  ordering + deep-link paths.
//

import Testing
import Foundation
import UIKit
@testable import gpscamera

private nonisolated struct StubProvider: SettingsProviding {
    var settingsSections: [SettingsSection] {
        [SettingsSection(id: "root", titleKey: "Root", items: [
            SettingItem(key: "stub.flag", titleKey: "Flag",
                        control: .toggle, defaultValue: .bool(true)),
            SettingItem(key: "stub.nav", titleKey: "Sub",
                        control: .navigation(sectionRef: "sub")),
        ]),
        SettingsSection(id: "sub", titleKey: "Sub", items: [
            SettingItem(key: "stub.choice", titleKey: "Choice",
                        control: .select([SelectOption(value: "a", titleKey: "A")]),
                        defaultValue: .string("a")),
            SettingItem(key: "stub.order", titleKey: "Order",
                        control: .orderList([OrderListOption(value: "x", titleKey: "X")]),
                        defaultValue: .stringList(["x"])),
            SettingItem(key: "stub.level", titleKey: "Level",
                        control: .stepper(range: 0...9, step: 1),
                        defaultValue: .number(3)),
        ])]
    }
}

/// Store + registry against an isolated UserDefaults suite.
struct SettingsStoreTests {
    let store: SettingsStore
    let registry: SettingsRegistry
    let suite = "settings-tests-\(UUID().uuidString)"

    init() {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = SettingsStore(defaults: defaults)
        registry = SettingsRegistry(providers: [StubProvider()],
                                    order: ["root": 10], store: store)
    }

    @Test func unsetKeysReadRegisteredDefaults() {
        #expect(store.bool("stub.flag") == true)
        #expect(store.string("stub.choice") == "a")
        #expect(store.number("stub.level") == 3)
        #expect(store.stringList("stub.order") == ["x"])
    }

    @Test func setValuesRoundTrip() {
        store.set(.bool(false), for: "stub.flag")
        store.set(.string("b"), for: "stub.choice")
        store.set(.number(7), for: "stub.level")
        store.set(.stringList(["y", "x"]), for: "stub.order")
        #expect(store.bool("stub.flag") == false)
        #expect(store.string("stub.choice") == "b")
        #expect(store.number("stub.level") == 7)
        #expect(store.stringList("stub.order") == ["y", "x"])
    }

    @Test func onlyOrderedSectionsAreTopLevel() {
        #expect(registry.topLevel.map(\.id) == ["root"])
        #expect(registry.section("sub") != nil)
    }

    @Test func deepLinkPathWalksNavigation() {
        #expect(registry.path(to: "stub.flag") == ["root"])
        #expect(registry.path(to: "stub.choice") == ["root", "sub"])
        #expect(registry.path(to: "missing").isEmpty)
    }
}

/// Every bundled font family must register and resolve, or the overlay font
/// select silently falls back to the system face.
struct BundledFontTests {
    /// UIFont(name:) nil = the family did not register; the overlay font
    /// select would silently fall back to the system face.
    /// (UIFont.familyNames is unreliable here: some registered fonts, e.g.
    /// Bebas Neue, resolve fine but never show up in that list.)
    @Test func allCatalogFamiliesResolve() {
        BundledFonts.registerAll()
        for family in OverlayFontCatalog.families {
            #expect(UIFont(name: family, size: 12) != nil,
                    "missing font family: \(family)")
        }
    }
}
