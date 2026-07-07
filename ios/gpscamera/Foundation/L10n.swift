//
//  L10n.swift
//  Foundation - l10n (foundation.md "L10n"). English source strings are the
//  L10nKeys; `L()` resolves them in the selected language and falls back to
//  the key itself, so an untranslated string renders as English.
//

import Combine
import Foundation

/// Resolves `key` in the selected language. Global on purpose: resolution
/// happens at every render site.
nonisolated func L(_ key: L10nKey) -> String { L10n.shared.string(key) }

/// Language selection + string lookup. The override ("" = follow the system)
/// persists as the `general.language` setting; screens that stay alive across
/// a change observe this object and re-render.
nonisolated final class L10n: ObservableObject {
    static let shared = L10n()
    static let settingKey = "general.language"

    /// Shipped languages (catalog locales) with their endonyms. Endonyms are
    /// picker labels shown untranslated - they are not L10nKeys.
    static let languages: [(code: String, endonym: String)] = [
        ("en", "English"),
        ("ko", "한국어"),
        ("ja", "日本語"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("es", "Español"),
        ("pt-BR", "Português (Brasil)"),
        ("de", "Deutsch"),
        ("fr", "Français"),
        ("it", "Italiano"),
        ("ru", "Русский"),
        ("nl", "Nederlands"),
        ("sv", "Svenska"),
        ("da", "Dansk"),
        ("nb", "Norsk bokmål"),
        ("fi", "Suomi"),
        ("pl", "Polski"),
        ("tr", "Türkçe"),
        ("ar", "العربية"),
        ("he", "עברית"),
        ("hi", "हिन्दी"),
        ("th", "ไทย"),
        ("vi", "Tiếng Việt"),
        ("id", "Indonesia"),
        ("ms", "Melayu"),
        ("cs", "Čeština"),
        ("el", "Ελληνικά"),
        ("uk", "Українська"),
        ("ro", "Română"),
        ("hu", "Magyar"),
    ]

    /// Current override code; "" while following the system.
    @Published private(set) var language: String
    private let lock = NSLock()
    private var bundle: Bundle

    init(defaults: UserDefaults = .standard) {
        let code = defaults.string(forKey: Self.settingKey) ?? ""
        language = code
        bundle = Self.bundle(for: code)
    }

    /// Bound by the composition root to the `general.language` setting write.
    func setLanguage(_ code: String) {
        lock.lock()
        bundle = Self.bundle(for: code)
        lock.unlock()
        DispatchQueue.main.async { self.language = code }
    }

    /// Thread-safe: overlay rasterization resolves strings off the main actor.
    func string(_ key: L10nKey) -> String {
        lock.lock(); defer { lock.unlock() }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// "" or an unknown code -> Bundle.main (system language pick).
    private static func bundle(for code: String) -> Bundle {
        guard !code.isEmpty,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
