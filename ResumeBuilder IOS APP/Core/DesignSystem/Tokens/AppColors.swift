import SwiftUI

enum AppColors {
    static let backgroundTop    = Color(hex: "0A0E1A")
    static let backgroundMid    = Color(hex: "0D1326")
    static let backgroundBottom = Color(hex: "080B17")
    static let glassStroke      = Color.white.opacity(0.08)
    static let glassTint        = Color.white.opacity(0.06)
    static let gradientStart    = Color(hex: "6366F1")
    static let gradientMid      = Color(hex: "8B5CF6")
    static let gradientEnd      = Color(hex: "3B82F6")
    static let accentCyan       = Color(hex: "22D3EE")
    static let accentViolet     = Color(hex: "A78BFA")
    static let accentSky        = Color(hex: "60A5FA")
    static let accentTeal       = Color(hex: "2DD4BF")
    static let textPrimary      = Color.white
    static let textSecondary    = Color.white.opacity(0.6)
    static let textTertiary     = Color.white.opacity(0.35)
}

// Hex color initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
