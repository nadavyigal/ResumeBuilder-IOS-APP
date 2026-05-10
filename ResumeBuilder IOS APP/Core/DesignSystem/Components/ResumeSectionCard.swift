import SwiftUI

enum SectionStatus {
    case optimized, improved, original

    var label: String {
        switch self {
        case .optimized: return "Optimized"
        case .improved:  return "Improved"
        case .original:  return "Original"
        }
    }

    var color: Color {
        switch self {
        case .optimized: return AppColors.accentTeal
        case .improved:  return AppColors.accentViolet
        case .original:  return AppColors.textSecondary
        }
    }
}

struct ResumeSectionCard: View {
    let icon: String
    let title: String
    let content: String
    let status: SectionStatus
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(status.color)

                Text(title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text(status.label)
                    .font(.appCaption)
                    .foregroundStyle(status.color)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 3)
                    .background(status.color.opacity(0.15), in: Capsule())

                if let onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(content)
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(3)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }
}

#Preview {
    VStack(spacing: 12) {
        ResumeSectionCard(
            icon: "person.fill",
            title: "Summary",
            content: "Results-driven software engineer with 5+ years of experience building scalable web applications.",
            status: .optimized
        ) {}
        ResumeSectionCard(
            icon: "briefcase.fill",
            title: "Experience",
            content: "Led development of core platform services at TechCorp, reducing latency by 40%.",
            status: .improved
        ) {}
    }
    .padding()
    .screenBackground()
}
