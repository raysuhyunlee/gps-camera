//
//  FoundationSettings.swift
//  Foundation - the foundation-owned Settings sections (foundation.md):
//  General (language), Send feedback, About (version, ToS, privacy).
//

import SwiftUI

/// Source-of-truth for the current app version (foundation.md "Version").
nonisolated enum AppVersion {
    static var current: String {
        let info = Bundle.main
        let version = info.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "?"
        let build = info.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }
}

/// The app's web endpoints (foundation.md "Misc").
nonisolated enum FoundationURL {
    static let feedback = URL(string: "https://www.raysuhyunlee.com/apps/gps-camera/feedback")!
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
