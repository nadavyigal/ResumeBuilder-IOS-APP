import SwiftUI

enum AppGradients {
    static let primary = LinearGradient(
        colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
        startPoint: UnitPoint(x: 0.15, y: 0), endPoint: UnitPoint(x: 0.85, y: 1)
    )

    static let cta = LinearGradient(
        colors: [Color(hex: "5A4FE0"), Color(hex: "2F6FD6"), Color(hex: "0E7C86")],
        startPoint: UnitPoint(x: 0.15, y: 0), endPoint: UnitPoint(x: 0.85, y: 1)
    )

    static let background = LinearGradient(
        colors: [AppColors.backgroundTop, AppColors.backgroundMid, AppColors.backgroundBottom],
        startPoint: .top, endPoint: .bottom
    )

    static let heroRing = LinearGradient(
        colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.accentSky],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
