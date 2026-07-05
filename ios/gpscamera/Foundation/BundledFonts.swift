//
//  BundledFonts.swift
//  Foundation - registers the bundled OFL fonts (Resources/Fonts) at startup.
//  Runtime registration via CoreText; no Info.plist UIAppFonts needed.
//

import CoreText
import Foundation

nonisolated enum BundledFonts {
    /// Idempotent; call once from the composition root before any UI renders.
    static func registerAll() {
        let bundle = Bundle.main
        let urls = (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        var seen = Set<String>()
        for url in urls where seen.insert(url.lastPathComponent).inserted {
            // Already-registered errors are fine; anything else is a packaging
            // bug we want to hear about in development.
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error),
               let error = error?.takeRetainedValue(),
               CFErrorGetCode(error) != CTFontManagerError.alreadyRegistered.rawValue {
                assertionFailure("font registration failed: \(url.lastPathComponent) \(error)")
            }
        }
    }
}
