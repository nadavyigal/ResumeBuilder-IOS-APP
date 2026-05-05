import SwiftUI

struct ScreenBackgroundModifier: ViewModifier {
    var showRadialGlow: Bool = false

    func body(content: Content) -> some View {
        ZStack {
            AppGradients.background
                .ignoresSafeArea()

            if showRadialGlow {
                RadialGradient(
                    colors: [AppColors.gradientMid.opacity(0.18), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
            }

            content
        }
    }
}

extension View {
    func screenBackground(showRadialGlow: Bool = false) -> some View {
        modifier(ScreenBackgroundModifier(showRadialGlow: showRadialGlow))
    }
}
