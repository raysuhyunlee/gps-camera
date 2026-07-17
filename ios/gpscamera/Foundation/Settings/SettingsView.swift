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
    /// Locked pro row tapped - routes to the paywall once monetization lands.
    var onProLock: (String) -> Void = { _ in }
    var highlightKey: String?
    /// Debug surface factory (composition root). Dev backdoor: 7 rapid taps on
    /// the title present it; intentionally undiscoverable. nil disables it.
    var debugScreen: (() -> AnyView)? = nil

    /// Re-renders the open screen when the language setting changes.
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    @State private var path: [String] = []
    @State private var highlight: String?
    /// Bumped on `.settingsGatingChanged` so gated rows re-read `entitled`
    /// while the screen is open (e.g. a purchase through the pro banner).
    @State private var gatingTick = 0
    @State private var titleTaps = 0
    @State private var lastTitleTap = Date.distantPast
    @State private var showDebug = false

    var body: some View {
        NavigationStack(path: $path) {
            HighlightingForm(highlight: highlight) {
                ForEach(registry.topLevel) { section in
                    SettingsSectionContent(section: section, store: store,
                                           entitled: entitled, onProLock: onProLock,
                                           highlight: $highlight)
                }
            }
            .navigationTitle(L("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Tappable stand-in for the inline title (the system title
                // itself takes no gestures); hosts the debug backdoor.
                ToolbarItem(placement: .principal) {
                    Text(L("Settings")).font(.headline)
                        .onTapGesture(perform: titleTapped)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showDebug) { debugScreen?() }
            .navigationDestination(for: String.self) { id in
                if let section = registry.section(id) {
                    HighlightingForm(highlight: highlight) {
                        SettingsSectionContent(section: section, store: store,
                                               entitled: entitled, onProLock: onProLock,
                                               highlight: $highlight)
                    }
                    .navigationTitle(L(section.titleKey))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: .settingsGatingChanged)) { _ in
            gatingTick += 1
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

    /// Rapid = under 1s between taps; a slower tap restarts the count.
    private func titleTapped() {
        guard debugScreen != nil else { return }
        let now = Date()
        titleTaps = now.timeIntervalSince(lastTitleTap) < 1 ? titleTaps + 1 : 1
        lastTitleTap = now
        if titleTaps == 7 {
            titleTaps = 0
            showDebug = true
        }
    }
}

/// Form that scrolls the deep-linked row into view once layout settles
/// (delay covers the sheet/push transition). Unknown ids are a no-op, so the
/// root and a pushed sub-section can both host the same highlight key.
private struct HighlightingForm<Content: View>: View {
    let highlight: String?
    @ViewBuilder let content: Content

    var body: some View {
        ScrollViewReader { proxy in
            Form { content }
                .task(id: highlight) {
                    guard let highlight else { return }
                    try? await Task.sleep(for: .milliseconds(400))
                    withAnimation { proxy.scrollTo(highlight, anchor: .center) }
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
        Section(L(section.titleKey)) {
            ForEach(visibleItems) { item in
                SettingRow(item: item, store: store,
                           entitled: entitled, onProLock: onProLock)
                    .id(item.key)   // scroll anchor for deep links
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
        let dimmed = !(item.enabledWhen?(store) ?? true)
        let row = VStack(alignment: .leading, spacing: 4) {
            HStack {
                control.disabled(locked || dimmed)
                if locked {
                    Image(systemName: "lock.fill").foregroundStyle(.secondary)
                }
            }
            if let footnote = item.footnoteKey {
                Text(L(footnote)).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .opacity(dimmed ? 0.4 : 1)
        if locked, !dimmed {
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
            Toggle(L(item.titleKey), isOn: toggleBinding)
        case .select(let options):
            let picker = Picker(L(item.titleKey), selection: stringBinding) {
                ForEach(options) {
                    Text(L($0.titleKey)).font($0.previewFont).tag($0.value)
                }
            }
            // Navigation-link style for previewed options (menus strip custom
            // fonts) and for long lists (e.g. the language picker).
            if options.contains(where: { $0.previewFont != nil }) || options.count > 8 {
                picker.pickerStyle(.navigationLink)
            } else {
                picker
            }
        case .stepper(let range, let step):
            Stepper(value: numberBinding, in: range, step: step) {
                LabeledContent(L(item.titleKey), value: format(store.number(item.key)))
            }
        case .slider(let range):
            VStack(alignment: .leading) {
                Text(L(item.titleKey))
                Slider(value: numberBinding, in: range)
            }
        case .color:
            ColorPicker(L(item.titleKey), selection: colorBinding)
        case .text:
            LabeledContent(L(item.titleKey)) {
                TextField("", text: stringBinding)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)   // renderer policy: settings text is
                                          // always a one-line "done" entry
            }
        case .orderList(let options):
            NavigationLink {
                OrderListEditor(title: L(item.titleKey), options: options,
                                included: stringListBinding)
            } label: {
                LabeledContent(L(item.titleKey),
                               value: summary(store.stringList(item.key), options))
            }
        case .navigation(let ref):
            NavigationLink(value: ref) { Text(L(item.titleKey)) }
        case .action(let perform):
            ActionRow(titleKey: item.titleKey, perform: perform)
        case .custom(let view):
            view()
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
        return included.compactMap { titles[$0].map(L) }.joined(separator: ", ")
    }
}

/// Action row: runs the domain handler with a trailing spinner, then presents
/// the returned feedback as an alert.
private struct ActionRow: View {
    let titleKey: L10nKey
    let perform: @MainActor () async -> ActionFeedback?
    @State private var running = false
    @State private var feedback: ActionFeedback?

    var body: some View {
        Button {
            Task {
                running = true
                feedback = await perform()
                running = false
            }
        } label: {
            HStack {
                Text(L(titleKey))
                Spacer()
                if running { ProgressView() }
            }
        }
        .disabled(running)
        .alert(L(feedback?.titleKey ?? ""), isPresented: .init(
            get: { feedback != nil },
            set: { if !$0 { feedback = nil } })) {
            Button(L("OK"), role: .cancel) {}
        } message: {
            if let message = feedback?.messageKey { Text(L(message)) }
        }
    }
}

/// orderList editor: drag to reorder the included items, swipe-delete to
/// exclude, tap an excluded item to include it.
private struct OrderListEditor: View {
    let title: String
    let options: [OrderListOption]
    @Binding var included: [String]

    /// Distinct row identity per section. Included and excluded rows must never
    /// share an id inside the one List: when an item switches sections, List
    /// diffing would reuse the old row (a ghost without edit accessories whose
    /// tap re-runs the include action, duplicating the item).
    private struct ExcludedRow: Identifiable {
        let option: OrderListOption
        var id: String { "excluded." + option.value }
    }

    var body: some View {
        List {
            Section(L("Included")) {
                ForEach(included, id: \.self) { id in
                    Text(label(id))
                }
                .onMove { included.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { included.remove(atOffsets: $0) }
            }
            let excluded = options.filter { !included.contains($0.value) }
                .map(ExcludedRow.init)
            if !excluded.isEmpty {
                Section(L("Excluded")) {
                    ForEach(excluded) { row in
                        Button {
                            withAnimation { include(row.option.value) }
                        } label: {
                            Label(L(row.option.titleKey), systemImage: "plus.circle.fill")
                        }
                        .moveDisabled(true)
                        .deleteDisabled(true)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(title)
    }

    private func include(_ value: String) {
        guard !included.contains(value) else { return }
        included.append(value)
    }

    private func label(_ id: String) -> String {
        options.first { $0.value == id }.map { L($0.titleKey) } ?? id
    }
}
