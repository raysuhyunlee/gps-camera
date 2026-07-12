//
//  FoundationSettings.swift
//  Foundation - the foundation-owned Settings sections (foundation.md):
//  General (language), Send feedback, About (version, ToS, privacy).
//

import SwiftUI

/// Source-of-truth for the current app version (foundation.md "Version").
nonisolated enum AppVersion {
    /// Marketing version only, e.g. "1.0.0".
    static var short: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "?"
    }
    /// Marketing version + build for display, e.g. "1.0.0 (12)".
    static var current: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}

/// The app's web endpoints (foundation.md "Misc").
nonisolated enum FoundationURL {
    /// Feedback page; carries the marketing version (`?version=1.0.0`) so the
    /// form can attribute reports to a release.
    static var feedback: URL {
        var c = URLComponents(string: "https://www.raysuhyunlee.com/apps/gps-camera/feedback")!
        c.queryItems = [URLQueryItem(name: "version", value: AppVersion.short)]
        return c.url!
    }
    static let tos = URL(string: "https://www.raysuhyunlee.com/apps/gps-camera/tos")!
    static let privacy = URL(string: "https://www.raysuhyunlee.com/apps/gps-camera/privacy")!
}

/// General / feedback / about sections (placement from overview.md).
nonisolated struct FoundationSettingsProvider: SettingsProviding {
    var settingsSections: [SettingsSection] {
        [SettingsSection(id: "foundation.general", titleKey: "General", items: [
            SettingItem(key: L10n.settingKey, titleKey: "Language",
                        control: .select(
                            [SelectOption(value: "", titleKey: "System default")]
                            + L10n.languages.map {
                                SelectOption(value: $0.code, titleKey: $0.endonym)
                            }),
                        defaultValue: .string("")),
        ]),
        SettingsSection(id: "foundation.feedback", titleKey: "", items: [
            SettingItem(key: "foundation.feedback", titleKey: "Send Feedback",
                        control: .action(perform: {
                            await UIApplication.shared.open(FoundationURL.feedback)
                            return nil
                        })),
        ]),
        SettingsSection(id: "foundation.about", titleKey: "About", items: [
            SettingItem(key: "foundation.about.version", titleKey: "Version",
                        control: .custom(view: {
                            AnyView(LabeledContent(L("Version"),
                                                   value: AppVersion.current))
                        })),
            SettingItem(key: "foundation.about.tos", titleKey: "Terms of Service",
                        control: .action(perform: {
                            await UIApplication.shared.open(FoundationURL.tos)
                            return nil
                        })),
            SettingItem(key: "foundation.about.privacy", titleKey: "Privacy Policy",
                        control: .action(perform: {
                            await UIApplication.shared.open(FoundationURL.privacy)
                            return nil
                        })),
        ])]
    }
}
