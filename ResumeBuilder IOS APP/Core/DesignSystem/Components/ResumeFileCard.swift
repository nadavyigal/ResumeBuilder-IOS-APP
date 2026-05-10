import SwiftUI

struct ResumeFileCard: View {
    let filename: String
    let metadata: String
    var onAction: (() -> Void)? = nil
    var actionIcon: String = "chevron.right"

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous)
                    .fill(AppColors.accentSky.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "doc.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.accentSky)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(filename)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text(metadata)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            if let onAction {
                Button(action: onAction) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }
}

#Preview {
    VStack(spacing: 12) {
        ResumeFileCard(filename: "Resume_2024.pdf", metadata: "2.3 MB · Uploaded today")
        ResumeFileCard(filename: "Design_Resume.pdf", metadata: "1.8 MB · Yesterday", onAction: {}, actionIcon: "square.and.arrow.down")
    }
    .padding()
    .screenBackground()
}
