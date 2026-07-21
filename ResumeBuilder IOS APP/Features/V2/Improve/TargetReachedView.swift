import SwiftUI

struct TargetReachedView: View {
    let score: Int
    let previousScore: Int?
    let onOpenDesign: () -> Void
    let onSaveProgress: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer(minLength: AppSpacing.xl)

            Text("RECRUITER-READY")
                .font(.caption.weight(.black))
                .kerning(1.2)
                .foregroundStyle(AppColors.accentCyan)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppColors.accentSky.opacity(0.24), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 260, height: 260)

                ScoreRingView(score: score, size: 190)
                    .scaleEffect(reduceMotion ? 1 : 1.02)

                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("out of 100")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            if let previousScore {
                Text("Up \(max(score - previousScore, 0)) points — from \(previousScore)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.accentCyan.opacity(0.14), in: Capsule())
            }

            Text("Your résumé is ready to send")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: AppSpacing.md) {
                nextMoveCard(
                    title: "Make it look the part",
                    subtitle: "Drop it into an ATS-friendly template",
                    systemImage: "paintbrush.fill",
                    tint: AppColors.accentViolet,
                    action: onOpenDesign
                )

                nextMoveCard(
                    title: "Lock in your progress",
                    subtitle: "Save free so you don't lose this",
                    systemImage: "lock.shield.fill",
                    tint: AppColors.accentCyan,
                    action: onSaveProgress
                )
            }

            Spacer(minLength: AppSpacing.xl)
        }
        .padding(.horizontal, Theme.pagePadding)
        .resumelyBackground(glow: AppColors.accentCyan)
    }

    private func nextMoveCard(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(AppSpacing.lg)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                    .strokeBorder(tint.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
