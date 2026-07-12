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
    /// nil = English: the keys are the English source strings, so English needs
    /// no bundle at all.
    private var bundle: Bundle?
    private var currentLocale: Locale

    init(defaults: UserDefaults = .standard) {
        let code = defaults.string(forKey: Self.settingKey) ?? ""
        language = code
        bundle = Self.bundle(for: code)
        currentLocale = Self.locale(for: code)
    }

    /// Bound by the composition root to the `general.language` setting write.
    func setLanguage(_ code: String) {
        lock.lock()
        bundle = Self.bundle(for: code)
        currentLocale = Self.locale(for: code)
        lock.unlock()
        DispatchQueue.main.async { self.language = code }
    }

    /// Thread-safe: overlay rasterization resolves strings off the main actor.
    func string(_ key: L10nKey) -> String {
        lock.lock(); defer { lock.unlock() }
        guard let bundle else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// The selected language as a `Locale`, for domains that format data rather
    /// than resolve strings (geocoded addresses, overlay timestamps).
    var locale: Locale {
        lock.lock(); defer { lock.unlock() }
        return currentLocale
    }

    /// English -> nil: it ships no lproj, and `Bundle.main` would hand back the
    /// *system* language (a Korean phone picking English would stay Korean).
    /// "" or an unknown code -> Bundle.main (system language pick).
    private static func bundle(for code: String) -> Bundle? {
        guard code != "en" else { return nil }
        guard !code.isEmpty,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }

    /// "" (follow the system) -> the device locale.
    private static func locale(for code: String) -> Locale {
        code.isEmpty ? .current : Locale(identifier: code)
    }
}
