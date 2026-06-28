import SwiftUI

struct SaveAccountSheetView: View {
    let score: Int
    let onContinueWithApple: () -> Void
    let onMaybeLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.sm)

            HStack(spacing: AppSpacing.md) {
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                    Text("SCORE")
                        .font(.system(size: 8, weight: .black))
                        .kerning(0.8)
                }
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(AppGradients.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Save your \(score)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Create a free account so this never disappears.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                keepRow("Your optimized résumé & score history")
                keepRow("Unlimited PDF exports, any template")
                keepRow("Sync across your iPhone & iPad")
            }
            .padding(AppSpacing.lg)
            .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                    .strokeBorder(AppColors.glassStroke, lineWidth: 1)
            )

            Button(action: onContinueWithApple) {
                Label("Continue with Apple", systemImage: "apple.logo")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AppColors.backgroundBottom)
                    .background(.white, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: onContinueWithApple) {
                Text("Continue with email")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AppColors.textPrimary)
                    .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous)
                            .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onMaybeLater) {
                Text("Maybe later")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Text("Your résumé stays private. We never sell or share your data.")
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.bottom, AppSpacing.lg)
        .presentationDetents([.medium, .large])
        .background(AppColors.backgroundBottom.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func keepRow(_ title: LocalizedStringKey) -> some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.textSecondary)
            .labelStyle(.titleAndIcon)
    }
}
