import SwiftUI
import UIKit
import WorldTrailsCore

/// Design tokens. Everything visual should come from here so the game stays cohesive.
enum Theme {
    // MARK: Color — "travel magazine": warm paper, deep ink, sun-faded accents.
    static let paper = Color(light: 0xF6F1E7, dark: 0x12151C)       // app background
    static let card = Color(light: 0xFFFDF8, dark: 0x1C2029)        // raised surfaces
    static let ink = Color(light: 0x1D2433, dark: 0xEDE6D8)         // primary text
    static let inkMuted = Color(light: 0x5C6474, dark: 0xA7A091)    // secondary text
    static let rule = Color(light: 0xE4DCCB, dark: 0x2C313C)        // hairlines
    static let terracotta = Color(light: 0xC4553A, dark: 0xE07A5F)  // primary action
    static let sea = Color(light: 0x2A7F8E, dark: 0x5BB3C1)         // map / info
    static let ochre = Color(light: 0xC98A1B, dark: 0xE3AC4A)       // XP / rewards
    static let success = Color(light: 0x3C8D5A, dark: 0x6CC08A)
    static let danger = Color(light: 0xB3392F, dark: 0xE06B60)

    static func tierColor(_ tier: StampTier) -> Color {
        switch tier {
        case .gold: return Color(light: 0xC9971C, dark: 0xF0C04F)
        case .silver: return Color(light: 0x7D8794, dark: 0xC3CAD3)
        case .bronze: return Color(light: 0x9C5B32, dark: 0xD08B5B)
        }
    }

    // MARK: Type — serif display for "editorial" headlines, system text for UI.
    static let display = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let title = Font.system(.title2, design: .serif).weight(.semibold)
    static let headline = Font.system(.headline, design: .default)
    static let body = Font.system(.body)
    static let caption = Font.system(.caption).weight(.medium)
    static let overline = Font.system(.caption2, design: .monospaced).weight(.semibold)
    static let score = Font.system(.title, design: .rounded).weight(.bold).monospacedDigit()

    // MARK: Layout
    static let gutter: CGFloat = 20
    static let radius: CGFloat = 18
    static let smallRadius: CGFloat = 12
}

extension Color {
    /// A color that adapts to light/dark mode from two hex values.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension ClueKind {
    var symbol: String {
        switch self {
        case .geography: return "globe.europe.africa"
        case .nature: return "leaf"
        case .culture: return "theatermasks"
        case .food: return "fork.knife"
        case .history: return "building.columns"
        case .landmark: return "mappin.and.ellipse"
        }
    }

    var label: String { rawValue.capitalized }
}

extension Rank {
    var symbol: String {
        switch self {
        case .explorer: return "figure.walk"
        case .pathfinder: return "map"
        case .adventurer: return "mountain.2"
        case .globetrotter: return "airplane"
        case .worldLegend: return "crown"
        }
    }
}
