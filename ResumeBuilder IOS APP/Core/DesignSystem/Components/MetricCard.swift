import SwiftUI

struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let subtitle: String
    var accentColor: Color = AppColors.accentViolet

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous)
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            Text(value)
                .font(.appMedNumeric)
                .foregroundStyle(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(subtitle)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: AppRadii.lg)
    }
}

#Preview {
    HStack {
        MetricCard(icon: "doc.text", label: "ATS Score", value: "82", subtitle: "Above average", accentColor: AppColors.accentTeal)
        MetricCard(icon: "star.fill", label: "Content", value: "74", subtitle: "Needs work", accentColor: AppColors.accentViolet)
    }
    .padding()
    .screenBackground()
}
