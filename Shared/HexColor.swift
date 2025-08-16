//
//  HexColor.swift
//  CloudNews
//
//  Created by Peter Hedlund on 6/29/21.
//

import SwiftUI

extension Color {
#if os(macOS)
    private typealias SystemColor = NSColor
#else
    private typealias SystemColor = UIColor
#endif

    private var uiColor: SystemColor {
        SystemColor(self)
    }

    typealias RGBA = (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)

    var rgba: RGBA? {
#if os(macOS)
        guard let components = uiColor.cgColor.components, components.count >= 4 else {
            return nil
        }
        return (components[0], components[1], components[2], components[3])
#else
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }
        return (r, g, b, a)
#endif
    }

    var hexaRGB: String? {
        guard let rgba else { return nil }
        func clamp(_ v: CGFloat) -> Int { min(max(Int(round(v * 255)), 0), 255) }
        return String(format: "#%02X%02X%02X", clamp(rgba.red), clamp(rgba.green), clamp(rgba.blue))
    }

    var hexaRGBA: String? {
        guard let rgba else { return nil }
        func clamp(_ v: CGFloat) -> Int { min(max(Int(round(v * 255)), 0), 255) }
        return String(format: "#%02X%02X%02X%02X", clamp(rgba.red), clamp(rgba.green), clamp(rgba.blue), clamp(rgba.alpha))
    }
}
