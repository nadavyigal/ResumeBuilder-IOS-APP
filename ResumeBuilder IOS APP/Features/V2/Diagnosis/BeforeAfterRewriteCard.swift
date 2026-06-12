import SwiftUI

struct BeforeAfterRewriteCard: View {
    let rewrite: BulletRewrite

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Before / after rewrite", systemImage: "arrow.triangle.2.circlepath")
                .font(.appCaption.weight(.bold))
                .foregroundStyle(AppColors.accentSky)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                bulletBlock(
                    label: "Before",
                    text: rewrite.before ?? "Original bullet unavailable",
                    icon: rewrite.hasOriginalBullet ? "minus.circle.fill" : "questionmark.circle.fill",
                    color: AppColors.textTertiary,
                    isPlaceholder: !rewrite.hasOriginalBullet
                )

                Divider()
                    .background(AppColors.glassStroke)

                bulletBlock(
                    label: "After",
                    text: rewrite.after,
                    icon: "checkmark.circle.fill",
                    color: AppColors.accentTeal,
                    isPlaceholder: false
                )
            }
            .padding(AppSpacing.md)
            .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))

            Text(rewrite.explanation)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .accessibilityElement(children: .combine)
    }

    private func bulletBlock(label: String, text: String, icon: String, color: Color, isPlaceholder: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label(label, systemImage: icon)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(color)

            Text(text)
                .font(.appSubheadline)
                .foregroundStyle(isPlaceholder ? AppColors.textTertiary : AppColors.textPrimary)
                .italic(isPlaceholder)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        BeforeAfterRewriteCard(rewrite: ResumeDiagnosis.sample().beforeAfter[0])
        BeforeAfterRewriteCard(
            rewrite: BulletRewrite(
                before: nil,
                after: "Built weekly reporting workflows that helped leadership prioritize renewal actions.",
                explanation: "Original text was not returned by the backend, so this card only shows the optimized direction."
            )
        )
    }
    .padding()
    .screenBackground(showRadialGlow: false)
    .preferredColorScheme(.dark)
}
