import SwiftUI

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = AppRadii.glass

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppColors.glassTint)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                    )
            }
            .glassShadow()
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = AppRadii.glass) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
