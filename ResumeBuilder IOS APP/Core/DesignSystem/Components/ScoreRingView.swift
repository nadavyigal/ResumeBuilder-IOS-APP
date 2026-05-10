import SwiftUI

struct ScoreRingView: View {
    let score: Int
    var size: CGFloat = 160
    var lineWidth: CGFloat = 14
    var animated: Bool = true

    @State private var animatedProgress: Double = 0

    private var progress: Double { max(0, min(1, Double(score) / 100.0)) }

    private var scoreColor: Color {
        switch score {
        case 80...100: return AppColors.accentTeal
        case 60..<80:  return AppColors.accentSky
        default:       return AppColors.accentViolet
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animated ? animatedProgress : progress)
                .stroke(
                    AppGradients.heroRing,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: animatedProgress)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.appLargeNumeric)
                    .foregroundStyle(AppColors.textPrimary)

                Text("/ 100")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if animated {
                animatedProgress = progress
            }
        }
        .onChange(of: score) {
            if animated {
                animatedProgress = progress
            }
        }
    }
}

#Preview {
    ScoreRingView(score: 78)
        .screenBackground()
}
