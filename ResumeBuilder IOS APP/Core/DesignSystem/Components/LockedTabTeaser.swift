import SwiftUI

struct LockedTabTeaser<Preview: View>: View {
    struct ChecklistItem: Identifiable {
        let id = UUID()
        let title: LocalizedStringKey
        let isComplete: Bool
    }

    let title: LocalizedStringKey
    let headline: LocalizedStringKey
    let previewCaption: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let checklist: [ChecklistItem]
    let ctaTitle: LocalizedStringKey
    let systemImage: String
    let onCTA: () -> Void
    @ViewBuilder let preview: () -> Preview

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

                previewCard

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
            .padding(.bottom, Theme.tabBarClearance)
        }
        .scrollBounceBehavior(.basedOnSize)
        .resumelyBackground(glow: AppColors.accentSky)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(previewCaption)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            ZStack {
                preview()
                    .blur(radius: 3)
                    .opacity(0.78)

                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(AppGradients.primary, in: Circle())
                        .shadow(color: AppColors.accentSky.opacity(0.35), radius: 18, y: 8)

                    Text("Unlock after Optimize")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 190)
            .padding(AppSpacing.md)
            .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(previewCaption))
        .accessibilityHint("Preview is locked until you optimize a resume")
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Unlock checklist")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

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

struct LockedScorePreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: 0.68)
                        .stroke(AppGradients.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("68")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        Text("/100")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .foregroundStyle(AppColors.textPrimary)
                }
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    metricRow("Keywords", value: "62")
                    metricRow("Format", value: "81")
                    metricRow("Impact", value: "58")
                }
            }

            Label("Biggest win: add missing keywords", systemImage: "trophy.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.accentViolet.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
        }
    }

    private func metricRow(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
            Spacer()
            Text(value)
                .font(.caption.weight(.black))
        }
        .foregroundStyle(AppColors.textSecondary)
    }
}

struct LockedExpertPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(["Cover letter", "Recruiter Qs", "Submit"], id: \.self) { title in
                    Text(title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 6)
                        .background(AppColors.glassTint, in: Capsule())
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Capsule().fill(AppColors.textPrimary.opacity(0.7)).frame(width: 150, height: 8)
                Capsule().fill(AppColors.textTertiary).frame(width: 220, height: 7)
                Capsule().fill(AppColors.textTertiary.opacity(0.75)).frame(width: 190, height: 7)
                Capsule().fill(AppColors.textTertiary.opacity(0.55)).frame(width: 235, height: 7)
                Capsule().fill(AppColors.accentCyan.opacity(0.6)).frame(width: 128, height: 7)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
        }
    }
}
