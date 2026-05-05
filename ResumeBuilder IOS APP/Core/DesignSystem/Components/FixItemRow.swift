import SwiftUI

enum ImpactLevel: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: Color {
        switch self {
        case .high:   return AppColors.accentTeal
        case .medium: return AppColors.accentViolet
        case .low:    return AppColors.accentSky
        }
    }
}

struct FixItemRow: View {
    let title: String
    let description: String
    let impact: ImpactLevel
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(impact.color.opacity(0.15))
                .frame(width: 8, height: 8)
                .overlay(Circle().fill(impact.color))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(description)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(impact.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(impact.color)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 3)
                .background(impact.color.opacity(0.12), in: Capsule())
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .contentShape(Rectangle())
        .onTapGesture { onAction?() }
    }
}

#Preview {
    VStack(spacing: 12) {
        FixItemRow(title: "Add missing keywords", description: "Include 'React', 'TypeScript' from the job posting", impact: .high)
        FixItemRow(title: "Quantify achievements", description: "Add metrics to your experience bullet points", impact: .medium)
    }
    .padding()
    .screenBackground()
}
