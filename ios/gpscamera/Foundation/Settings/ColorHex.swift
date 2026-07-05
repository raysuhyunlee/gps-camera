//
//  ColorHex.swift
//  Foundation - color <-> "#RRGGBBAA" for `Control.color` persistence.
//

import SwiftUI

extension Color {
    init(settingHex hex: String) {
        var value: UInt64 = 0
        let scanner = Scanner(string: String(hex.dropFirst(hex.hasPrefix("#") ? 1 : 0)))
        scanner.scanHexInt64(&value)
        self.init(red: Double((value >> 24) & 0xFF) / 255,
                  green: Double((value >> 16) & 0xFF) / 255,
                  blue: Double((value >> 8) & 0xFF) / 255,
                  opacity: Double(value & 0xFF) / 255)
    }

    var settingHex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> UInt64 { UInt64((max(0, min(1, v)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X%02X", c(r), c(g), c(b), c(a))
    }
}
