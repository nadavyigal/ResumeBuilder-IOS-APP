import SwiftUI

/// Displays the fit verdict result: band header, score ring, top gaps, missing keywords, and CTAs.
/// Reached after `FitCheckView` completes a successful check.
struct FitVerdictView: View {
    let result: FitCheckResult
    @Bindable var viewModel: FitCheckViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                bandHeader
                scoreSection
                if !result.verdict.topGaps.isEmpty {
                    gapsSection
                }
                if !result.verdict.missingKeywords.isEmpty {
                    keywordsSection
                }
                ctaSection
                scoreDisclaimer
                Spacer(minLength: AppSpacing.xxl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(NSLocalizedString("Your Fit", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("Back", comment: "")) {
                    viewModel.resetToEntry()
                }
                .foregroundStyle(AppColors.accentTeal)
            }
        }
    }

    // MARK: - Band header

    private var bandHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(bandLabel)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(bandColor)

            Text(bandDescription)
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(bandColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var bandLabel: String {
        switch result.verdict.band {
        case .strong: return NSLocalizedString("Strong Fit", comment: "")
        case .stretch: return NSLocalizedString("Stretch Fit", comment: "")
        case .skip: return NSLocalizedString("Weak Fit", comment: "")
        }
    }

    private var bandDescription: String {
        switch result.verdict.band {
        case .strong:
            return NSLocalizedString(
                "Your resume signals align well with this role. A few tweaks could make it even stronger.",
                comment: ""
            )
        case .stretch:
            return NSLocalizedString(
                "You could compete for this role, but there are key gaps to close before applying.",
                comment: ""
            )
        case .skip:
            return NSLocalizedString(
                "Your current resume is a weak match for this role. Consider targeting a closer fit first.",
                comment: ""
            )
        }
    }

    private var bandColor: Color {
        switch result.verdict.band {
        case .strong: return AppColors.accentTeal
        case .stretch: return Color.orange
        case .skip: return Color.red
        }
    }

    // MARK: - Score ring

    private var scoreSection: some View {
        VStack(spacing: AppSpacing.md) {
            ScoreRingView(score: result.verdict.score, size: 120)

            Text(NSLocalizedString("Resumely Match Score", comment: ""))
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Top gaps

    private var gapsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                icon: "exclamationmark.triangle.fill",
                title: NSLocalizedString("Key Gaps", comment: ""),
                color: Color.orange
            )

            ForEach(result.verdict.topGaps.prefix(3)) { gap in
                gapRow(gap)
            }
        }
        .padding(AppSpacing.lg)
        .glassCard()
    }

    private func gapRow(_ gap: ResumeGap) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Circle()
                .fill(severityColor(gap.severity))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(gap.title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
                if gap.explanation != gap.title, !gap.explanation.isEmpty {
                    Text(gap.explanation)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func severityColor(_ severity: GapSeverity) -> Color {
        switch severity {
        case .high: return Color.red
        case .medium: return Color.orange
        case .low: return AppColors.accentTeal
        }
    }

    // MARK: - Missing keywords

    private var keywordsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                icon: "key.fill",
                title: NSLocalizedString("Missing Keywords", comment: ""),
                color: AppColors.accentViolet
            )

            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(Array(result.verdict.missingKeywords.prefix(8).enumerated()), id: \.offset) { _, kw in
                    Text(kw.keyword)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.accentViolet.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(AppSpacing.lg)
        .glassCard()
    }

    // MARK: - CTAs

    private var ctaSection: some View {
        VStack(spacing: AppSpacing.md) {
            GradientButton(title: "Optimize for This Job") {
                viewModel.optimizeForThisJob()
            }

            // The target stays changeable right up to the moment of optimizing.
            Button(NSLocalizedString("Edit target job", comment: "")) {
                viewModel.editTarget()
            }
            .font(.appBody)
            .foregroundStyle(AppColors.accentSky)

            Button(NSLocalizedString("Skip — Browse Other Jobs", comment: "")) {
                viewModel.skip()
            }
            .font(.appBody)
            .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Score disclaimer

    private var scoreDisclaimer: some View {
        Text(result.verdict.scoreNote)
            .font(.appCaption)
            .foregroundStyle(AppColors.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .imageScale(.small)
            Text(title)
                .font(.appHeadline)
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}

// FlowLayout is defined in RecruiterEyeViewCard.swift and shared project-wide.

#Preview {
    NavigationStack {
        FitVerdictView(
            result: FitCheckResult(
                verdict: FitVerdict(
                    band: .stretch,
                    score: 68,
                    scoreNote: FitVerdict.defaultScoreNote,
                    topGaps: [
                        ResumeGap(title: "Cloud infra evidence is light", explanation: "JD asks for AWS and Terraform; your resume doesn't mention them.", severity: .high),
                        ResumeGap(title: "Leadership scope needs metrics", explanation: "Add numbers where they match your experience.", severity: .medium),
                        ResumeGap(title: "No monitoring/observability tools mentioned", explanation: "Role expects Datadog or similar.", severity: .low),
                    ],
                    missingKeywords: [
                        ResumeKeyword(keyword: "Terraform", importance: .high),
                        ResumeKeyword(keyword: "AWS", importance: .high),
                        ResumeKeyword(keyword: "Kafka", importance: .medium),
                        ResumeKeyword(keyword: "Redis", importance: .medium),
                    ]
                ),
                sessionId: "preview",
                checksRemaining: 3
            ),
            viewModel: {
                let vm = FitCheckViewModel(fitCheckService: MockFitCheckService())
                vm.jobDescription = "Sample job description"
                return vm
            }()
        )
    }
    .preferredColorScheme(.dark)
}
