import SwiftUI

struct LockedTabTeaser: View {
    struct ChecklistItem: Identifiable {
        let id = UUID()
        let title: LocalizedStringKey
        let isComplete: Bool
    }

    let title: LocalizedStringKey
    let headline: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let checklist: [ChecklistItem]
    let ctaTitle: LocalizedStringKey
    let systemImage: String
    var recoveryState: OptimizationRecoveryState = .idle
    var onRetryRecovery: () -> Void = {}
    let onCTA: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(title)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(headline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                recoveryCard

                checklistCard

                Button(action: onCTA) {
                    Label(ctaTitle, systemImage: "arrow.up.forward.circle.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(AppGradients.primary, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the Home tab")
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .resumelyBackground(glow: AppColors.accentSky)
    }

    @ViewBuilder
    private var recoveryCard: some View {
        switch recoveryState {
        case .loading:
            HStack(spacing: AppSpacing.md) {
                ProgressView()
                    .tint(AppColors.accentCyan)
                Text("Checking your saved optimizations…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: AppRadii.lg)
            .accessibilityLabel("Checking your saved optimizations")
        case .failed:
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Label("We couldn't restore your latest optimization.", systemImage: "arrow.clockwise.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Check your connection, then try again.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Button("Try restoring again", action: onRetryRecovery)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.accentSky)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: AppRadii.lg)
        case .idle, .ready, .recovered, .empty:
            EmptyView()
        }
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label {
                Text("Unlock checklist")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppGradients.primary)
            }

            ForEach(checklist) { item in
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(item.isComplete ? AppColors.accentCyan : AppColors.textTertiary)

                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(item.title))
                .accessibilityValue(item.isComplete ? "Complete" : "Not complete")
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }
}
