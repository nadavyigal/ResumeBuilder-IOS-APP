import SwiftUI

enum Theme {
    static var primaryGradient: LinearGradient { AppGradients.primary }
    static var backgroundGradient: LinearGradient { AppGradients.background }
    static var background: Color { AppColors.backgroundBottom }
    static var surface: Color { AppColors.glassTint }
    static var textPrimary: Color { AppColors.textPrimary }
    static var textSecondary: Color { AppColors.textSecondary }
    static var accent: Color { AppColors.gradientMid }
}
