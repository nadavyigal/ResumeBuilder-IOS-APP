import SwiftUI

struct ATSDial: View {
    let score: Int

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let progress = max(0, min(1, Double(score) / 100.0))
            let lineWidth: CGFloat = size * 0.12

            ZStack {
                // Track
                Circle()
                    .stroke(Theme.bgCard, lineWidth: lineWidth)

                // Arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Theme.accent, Theme.accentBlue, Theme.accentCyan]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.55, dampingFraction: 0.75), value: progress)

                // Score label
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("/ 100")
                        .font(.system(size: size * 0.12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .frame(width: size, height: size)
        }
    }
}
