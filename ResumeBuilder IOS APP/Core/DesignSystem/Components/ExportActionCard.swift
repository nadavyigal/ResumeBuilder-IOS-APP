import SwiftUI

struct ExportActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var accentColor: Color = AppColors.accentSky
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 48, height: 48)

                    if isLoading {
                        ProgressView()
                            .tint(accentColor)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(subtitle)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)
        }
        .buttonStyle(GradientButtonStyle())
        .disabled(isLoading)
    }
}

#Preview {
    VStack(spacing: 12) {
        ExportActionCard(icon: "arrow.down.circle.fill", title: "Download PDF", subtitle: "Save to Files app", accentColor: AppColors.accentTeal) {}
        ExportActionCard(icon: "square.and.arrow.up", title: "Share", subtitle: "Send via email or message", accentColor: AppColors.accentSky) {}
        ExportActionCard(icon: "bookmark.fill", title: "Save Version", subtitle: "Keep a copy in history", accentColor: AppColors.accentViolet) {}
    }
    .padding()
    .screenBackground()
}
