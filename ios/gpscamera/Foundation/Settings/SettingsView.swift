//
//  SettingsView.swift
//  Foundation - generic Settings renderer. Knows no domain: renders whatever
//  sections the registry holds (foundation.md "Settings Framework").
//

import SwiftUI

/// The Settings screen. Presents the registry's top-level sections and pushes
/// sub-sections via `Control.navigation`. `highlightKey` deep-links to an item:
/// navigates to its section and transiently highlights the row.
struct SettingsScreen: View {
    let registry: SettingsRegistry
    @ObservedObject var store: SettingsStore
    /// Pro entitlement (from monetization at the composition root).
    var entitled: () -> Bool = { false }
    /// Locked pro row tapped — routes to the paywall once monetization lands.
    var onProLock: (String) -> Void = { _ in }
    var highlightKey: String?

    @Environment(\.dismiss) private var dismiss
    @State private var path: [String] = []
    @State private var highlight: String?

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                ForEach(registry.topLevel) { section in
                    SettingsSectionContent(section: section, store: store,
                                           entitled: entitled, onProLock: onProLock,
                                           highlight: $highlight)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: String.self) { id in
                if let section = registry.section(id) {
                    Form {
                        SettingsSectionContent(section: section, store: store,
                                               entitled: entitled, onProLock: onProLock,
                                               highlight: $highlight)
                    }
                    .navigationTitle(section.titleKey)
                }
            }
        }
        .onAppear {
            guard let key = highlightKey else { return }
            // Sub-section chain below the root screen (root sections are inline).
            path = Array(registry.path(to: key).dropFirst())
            highlight = key
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { highlight = nil }
            }
        }
    }
}

/// One section's rows. Used inline on the root screen and as a pushed page.
private struct SettingsSectionContent: View {
    let section: SettingsSection
    @ObservedObject var store: SettingsStore
    let entitled: () -> Bool
    let onProLock: (String) -> Void
    @Binding var highlight: String?

    var body: some View {
        Section(section.titleKey) {
            ForEach(visibleItems) { item in
                SettingRow(item: item, store: store,
                           entitled: entitled, onProLock: onProLock)
                    .listRowBackground(highlight == item.key
                                       ? Color.accentColor.opacity(0.25) : nil)
            }
        }
    }

    private var visibleItems: [SettingItem] {
        section.items.filter { $0.visibleWhen?(store) ?? true }
    }
}

/// One item row: renders the control generically, applies pro gating and
/// permission-coupled toggle acquisition.
private struct SettingRow: View {
    let item: SettingItem
    @ObservedObject var store: SettingsStore
    let entitled: () -> Bool
    let onProLock: (String) -> Void

    var body: some View {
        let locked = item.gate == .pro && !entitled()
        let row = VStack(alignment: .leading, spacing: 4) {
            HStack {
                control.disabled(locked)
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                }
            }
            if let footnote = item.footnoteKey {
                Text(footnote).font(.footnote).foregroundStyle(.secondary)
            }
        }
        if locked {
            row.contentShape(Rectangle())
                .onTapGesture { onProLock(item.key) }   // -> paywall (monetization)
        } else {
            row
        }
    }

    @ViewBuilder
    private var control: some View {
        switch item.control {
        case .toggle:
            Toggle(item.titleKey, isOn: toggleBinding)
        case .select(let options):
            Picker(item.titleKey, selection: stringBinding) {
                ForEach(options) { Text($0.titleKey).tag($0.value) }
            }
        case .stepper(let range, let step):
            Stepper(value: numberBinding, in: range, step: step) {
                LabeledContent(item.titleKey, value: format(store.number(item.key)))
            }
        case .slider(let range):
            VStack(alignment: .leading) {
                Text(item.titleKey)
                Slider(value: numberBinding, in: range)
            }
        case .color:
            ColorPicker(item.titleKey, selection: colorBinding)
        case .text:
            LabeledContent(item.titleKey) {
                TextField("", text: stringBinding)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        case .orderList(let options):
            NavigationLink {
                OrderListEditor(title: item.titleKey, options: options,
                                included: stringListBinding)
            } label: {
                LabeledContent(item.titleKey,
                               value: summary(store.stringList(item.key), options))
            }
        case .navigation(let ref):
            NavigationLink(value: ref) { Text(item.titleKey) }
        case .action:
            Button(item.titleKey) {}   // handlers land with their features
                .disabled(true)
        case .custom:
            Text(item.titleKey)        // domain view slots in when provided
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bindings

    /// Enabling a permission-coupled item requests the permission; denial flips
    /// the item back off (foundation.md "Acquiring permission").
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { store.bool(item.key) },
            set: { on in
                store.set(.bool(on), for: item.key)
                guard on, let permission = item.requiresPermission,
                      SettingsPermissions.status(permission) != .authorized else { return }
                SettingsPermissions.request(permission) { status in
                    if status != .authorized { store.set(.bool(false), for: item.key) }
                }
            })
    }

    private var stringBinding: Binding<String> {
        Binding(get: { store.string(item.key) },
                set: { store.set(.string($0), for: item.key) })
    }

    private var numberBinding: Binding<Double> {
        Binding(get: { store.number(item.key) },
                set: { store.set(.number($0), for: item.key) })
    }

    private var stringListBinding: Binding<[String]> {
        Binding(get: { store.stringList(item.key) },
                set: { store.set(.stringList($0), for: item.key) })
    }

    private var colorBinding: Binding<Color> {
        Binding(get: { Color(settingHex: store.string(item.key)) },
                set: { store.set(.string($0.settingHex), for: item.key) })
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func summary(_ included: [String], _ options: [OrderListOption]) -> String {
        let titles = Dictionary(uniqueKeysWithValues: options.map { ($0.value, $0.titleKey) })
        return included.compactMap { titles[$0] }.joined(separator: ", ")
    }
}

/// orderList editor: drag to reorder the included items, swipe-delete to
/// exclude, tap an excluded item to include it.
private struct OrderListEditor: View {
    let title: String
    let options: [OrderListOption]
    @Binding var included: [String]

    var body: some View {
        List {
            Section("Included") {
                ForEach(included, id: \.self) { id in
                    Text(label(id))
                }
                .onMove { included.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { included.remove(atOffsets: $0) }
            }
            let excluded = options.filter { !included.contains($0.value) }
            if !excluded.isEmpty {
                Section("Excluded") {
                    ForEach(excluded) { option in
                        Button {
                            withAnimation { included.append(option.value) }
                        } label: {
                            Label(option.titleKey, systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(title)
    }

    private func label(_ id: String) -> String {
        options.first { $0.value == id }?.titleKey ?? id
    }
}
