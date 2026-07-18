//
//  L10n.swift
//  Foundation - l10n (foundation.md "L10n"). English source strings are the
//  L10nKeys; `L()` resolves them in the app language and falls back to the
//  key itself, so an untranslated string renders as English.
//

import Foundation

/// Resolves `key` in the app language. Global on purpose: resolution
/// happens at every render site.
nonisolated func L(_ key: L10nKey) -> String { L10n.shared.string(key) }

/// String lookup in the app language. iOS owns language selection (Settings >
/// Apps > GPS Camera > Language), so resolution follows `Bundle.main`; the
/// DEBUG screenshot pipeline overrides it per run via `setLanguage`.
nonisolated final class L10n {
    static let shared = L10n()

    /// Shipped languages (catalog locales); drives the screenshot pipeline's
    /// store-locale mapping.
    static let languages = [
        "en", "ko", "ja", "zh-Hans", "zh-Hant", "es", "pt-BR", "de", "fr",
        "it", "ru", "nl", "sv", "da", "nb", "fi", "pl", "tr", "ar", "he",
        "hi", "th", "vi", "id", "ms", "cs", "el", "uk", "ro", "hu",
    ]

    private let lock = NSLock()
    /// nil = English under a screenshot override: the keys are the English
    /// source strings, so English needs no bundle at all. `.main` otherwise:
    /// iOS resolves it in the per-app language.
    private var bundle: Bundle? = .main
    private var currentLocale: Locale = .current

    /// Screenshot-demo override (screenshots.md): forces one shipped language
    /// for the run regardless of the simulator's system language.
    func setLanguage(_ code: String) {
        lock.lock()
        bundle = Self.bundle(for: code)
        currentLocale = code.isEmpty ? .current : Locale(identifier: code)
        lock.unlock()
    }

    /// Thread-safe: overlay rasterization resolves strings off the main actor.
    func string(_ key: L10nKey) -> String {
        lock.lock(); defer { lock.unlock() }
        guard let bundle else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// The app language as a `Locale`, for domains that format data rather
    /// than resolve strings (geocoded addresses, overlay timestamps).
    var locale: Locale {
        lock.lock(); defer { lock.unlock() }
        return currentLocale
    }

    /// English -> nil: it ships no lproj, and `Bundle.main` would hand back the
    /// *system* language (an English screenshot run on a Korean simulator would
    /// stay Korean). "" or an unknown code -> Bundle.main (system language).
    private static func bundle(for code: String) -> Bundle? {
        guard code != "en" else { return nil }
        guard !code.isEmpty,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
