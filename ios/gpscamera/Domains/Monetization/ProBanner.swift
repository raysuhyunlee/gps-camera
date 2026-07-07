//
//  ProBanner.swift
//  Monetization - the pro banner (monetization.md "Pro banner"): a thin
//  tappable strip on Main, a thicker CTA row in Settings. Both route to the
//  paywall themselves; hosts stay monetization-unaware.
//

import SwiftUI

/// Seam consumed by Main (overview.md "Domain wiring"): the thin one-line
/// banner hosted under the top control section.
protocol ProBannerProviding {
    func mainBanner() -> AnyView
}

extension ProStore: ProBannerProviding {
    func mainBanner() -> AnyView { AnyView(MainProBanner(store: self)) }
}

/// Contributes the Settings pro-banner and restore sections (order assigned
/// at the root).
struct MonetizationSettingsProvider: SettingsProviding {
    let store: ProStore

    var settingsSections: [SettingsSection] {
        [SettingsSection(id: "monetization", titleKey: "", items: [
            SettingItem(key: "monetization.proBanner", titleKey: "GPS Camera Pro",
                        control: .custom(view: { [store] in
                            AnyView(SettingsProBanner(store: store))
                        })),
        ]),
        SettingsSection(id: "monetization.restore", titleKey: "", items: [
            SettingItem(key: "monetization.restore", titleKey: "Restore Purchase",
                        control: .action(perform: { [store] in
                            do {
                                return try await store.restore()
                                    ? ActionFeedback(titleKey: "Purchases Restored",
                                                     messageKey: "GPS Camera Pro is active.")
                                    : ActionFeedback(titleKey: "No previous purchase was found.")
                            } catch {
                                return ActionFeedback(titleKey: "Restore could not be completed. Please try again.")
                            }
                        })),
        ])]
    }
}

/// Main: one line, no CTA - the banner itself opens the paywall. Hidden for pro.
private struct MainProBanner: View {
    @ObservedObject var store: ProStore
    @State private var showPaywall = false

    var body: some View {
        if store.entitlement == .free {
            Button { showPaywall = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(L("Get GPS Camera Pro"))
                        .font(.caption.bold())
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.4), in: Capsule())
            }
            .padding(.top, 8)
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store, source: .mainBanner)
            }
        }
    }
}

/// Settings: thicker two-line banner with a CTA. Free nudges to upgrade;
/// subscribed shows status + manage (hidden when there is no management URL,
/// e.g. lifetime).
private struct SettingsProBanner: View {
    @ObservedObject var store: ProStore
    @Environment(\.openURL) private var openURL
    @State private var showPaywall = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pro ? "checkmark.seal.fill" : "crown.fill")
                .font(.title2)
                .foregroundStyle(pro ? Color.accentColor : .yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("GPS Camera Pro"))
                    .font(.headline)
                Text(L(pro ? "All features available" : "No ads, every feature unlocked"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if pro {
                if let url = store.managementURL {
                    Button(L("Manage")) { openURL(url) }
                        .buttonStyle(.bordered)
                }
            } else {
                Button(L("Upgrade")) { showPaywall = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: store, source: .settingsBanner)
        }
    }

    private var pro: Bool { store.entitlement == .pro }
}
