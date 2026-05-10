import SwiftUI

enum Theme {
    static var primaryGradient: LinearGradient { AppGradients.primary }
    static var backgroundGradient: LinearGradient { AppGradients.background }
    static var background: Color { AppColors.backgroundBottom }
    static var surface: Color { AppColors.glassTint }
    static var textPrimary: Color { AppColors.textPrimary }
    static var textSecondary: Color { AppColors.textSecondary }
    static var accent: Color { AppColors.gradientMid }
    static var bgPrimary: Color { AppColors.backgroundBottom }
    static var bgCard: Color { AppColors.backgroundMid }
    static var canvas: Color { Color(uiColor: .systemBackground) }
    static var accentBlue: Color { AppColors.accentSky }
    static var accentCyan: Color { AppColors.accentCyan }
    static var textTertiary: Color { AppColors.textTertiary }
    static var primary: Color { bgPrimary }
    static var brandGradient: LinearGradient { AppGradients.primary }
    static var bgGradient: LinearGradient { AppGradients.background }
    static var cyanGradient: LinearGradient {
        LinearGradient(
            colors: [AppColors.accentCyan, AppColors.accentSky],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    static let radiusCard: CGFloat = 16
    static let radiusButton: CGFloat = 14
    static let radiusBadge: CGFloat = 10
    static let pagePadding: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let sectionGap: CGFloat = 24
    static let tabBarClearance: CGFloat = 100
}

extension View {
    func resumelyBackground(glow: Color = .clear) -> some View {
        background(
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()
                if glow != .clear {
                    RadialGradient(
                        colors: [glow.opacity(0.13), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: 380
                    )
                    .ignoresSafeArea()
                }
            }
        )
    }
}
