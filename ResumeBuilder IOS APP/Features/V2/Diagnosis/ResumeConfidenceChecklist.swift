import SwiftUI

struct ResumeConfidenceChecklist: View {
    let items: [ConfidenceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label("Confidence checklist", systemImage: "checklist.checked")
                    .font(.appCaption.weight(.bold))
                    .foregroundStyle(AppColors.accentTeal)

                Text("Why this version is more aligned before export.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: AppSpacing.sm) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(item.isComplete ? AppColors.accentTeal : AppColors.textTertiary)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.appCaption.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            if let explanation = item.explanation {
                                Text(explanation)
                                    .font(.appCaption)
                                    .foregroundStyle(AppColors.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }
}

#Preview {
    ResumeConfidenceChecklist(items: ResumeDiagnosis.sample().confidenceChecklist)
        .padding()
        .screenBackground(showRadialGlow: false)
        .preferredColorScheme(.dark)
}
