import SwiftUI

/// Recovery state for a connectivity drop during optimize/ATS-check.
/// Retry is manual (no NWPathMonitor-driven auto-resume exists yet), and the
/// "nothing's lost" copy is honest only within the current app session — inputs
/// live in TailorViewModel state, not a durable on-disk checkpoint.
struct ConnectionLostView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "wifi.slash")
                    .font(.caption.weight(.bold))
                Text("You're offline")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(Color(hex: "FFD479"))

            VStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                        .frame(width: 84, height: 84)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(Color(hex: "FFD479"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 84, height: 84)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "pause.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "FFD479"))
                }

                Text("Connection dropped")
                    .font(.title3.weight(.black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Your résumé and job details are still here — nothing's lost. Retry when you're back online.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            Button(action: onRetry) {
                Label("Retry now", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(.white)
                    .background(AppGradients.primary, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(hex: "FFD479").opacity(0.18), lineWidth: 1)
        )
    }
}

#Preview {
    ConnectionLostView(onRetry: {})
        .padding()
        .resumelyBackground(glow: AppColors.accentSky)
        .preferredColorScheme(.dark)
}
