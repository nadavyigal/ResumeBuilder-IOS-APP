import SwiftUI

struct WaveDecoration: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: h * 0.6))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.4),
            control1: CGPoint(x: w * 0.3, y: h * 0.2),
            control2: CGPoint(x: w * 0.7, y: h * 0.8)
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

struct WaveDecorationView: View {
    var body: some View {
        WaveDecoration()
            .stroke(Color.white.opacity(0.06), lineWidth: 1.5)
            .frame(height: 60)
            .allowsHitTesting(false)
    }
}
