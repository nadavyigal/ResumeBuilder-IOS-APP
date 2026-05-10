import SwiftUI

struct GlassShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 8)
    }
}

extension View {
    func glassShadow() -> some View {
        modifier(GlassShadowModifier())
    }
}
