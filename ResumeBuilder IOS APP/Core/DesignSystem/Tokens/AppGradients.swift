import SwiftUI

enum AppGradients {
    static let primary = LinearGradient(
        colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
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
