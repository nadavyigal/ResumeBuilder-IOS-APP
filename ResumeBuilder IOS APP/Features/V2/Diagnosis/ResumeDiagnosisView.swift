import SwiftUI

@MainActor
struct ResumeDiagnosisView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ResumeDiagnosisViewModel
    var onImprove: () -> Void
    var onEditTargetJob: () -> Void

    @State private var viewedRewriteIds: Set<UUID> = []
    @State private var blockedRewriteIds: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header

                if viewModel.isLoading && viewModel.diagnosis == nil {
                    loadingState
                } else if let diagnosis = viewModel.diagnosis {
                    successState(diagnosis)
                } else if let error = viewModel.errorMessage {
                    errorState(error)
                } else {
                    emptyState
                }

                Spacer(minLength: 96)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .screenBackground(showRadialGlow: true)
        .navigationTitle("Resume Diagnosis")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(appState: appState)
            AnalyticsService.shared.track(.diagnosisViewed(matchScore: viewModel.diagnosis?.matchScore ?? 0))
        }
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label("FIRST READ", systemImage: "doc.text.magnifyingglass")
                .font(.appCaption.weight(.bold))
                .foregroundStyle(AppColors.accentTeal)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 5)
                .background(AppColors.accentTeal.opacity(0.12), in: Capsule())

            Text("Here is what the job sees")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("A compact diagnosis of fit, gaps, missing signals, and the next best fix.")
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func successState(_ diagnosis: ResumeDiagnosis) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            scoreCard(diagnosis)
            topGapsCard(diagnosis.topGaps)
            missingKeywordsCard(diagnosis)
            RecruiterEyeViewCard(review: diagnosis.recruiterReview)

            if let rewrite = diagnosis.beforeAfter.first {
                BeforeAfterRewriteCard(rewrite: rewrite)
                    .onAppear { markRecommendationViewed(rewrite) }
            }

            ResumeConfidenceChecklist(items: diagnosis.confidenceChecklist)
        }
    }

    private func markRecommendationViewed(_ rewrite: BulletRewrite) {
        guard viewedRewriteIds.insert(rewrite.id).inserted else { return }
        let safety = RecommendationSafetyPolicy.assess(
            before: rewrite.before,
            after: rewrite.after,
            context: rewrite.explanation
        )
        AnalyticsService.shared.track(
            .recommendationViewed(
                surface: "diagnosis",
                safetyState: safety.analyticsState,
                reviewId: nil,
                itemId: rewrite.id.uuidString
            )
        )
        if safety.isSuppressed, blockedRewriteIds.insert(rewrite.id).inserted {
            AnalyticsService.shared.track(
                .recommendationBlocked(
                    surface: "diagnosis",
                    reason: safety.analyticsReason,
                    reviewId: nil,
                    itemId: rewrite.id.uuidString
                )
            )
        }
    }

    private func scoreCard(_ diagnosis: ResumeDiagnosis) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .center, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Resume Match Score")
                        .font(.appCaption.weight(.bold))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("Your resume matches about \(diagnosis.matchScore)% of this job")
                        .font(.appHeadline)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.sm)

                ScoreRingView(score: diagnosis.matchScore, size: 92)
            }

            if let potential = diagnosis.potentialScore {
                Label("Potential after optimization: about \(potential)%", systemImage: "arrow.up.circle.fill")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.accentTeal)
            }

            Text(diagnosis.scoreNote.isEmpty ? diagnosis.matchScoreLabel : diagnosis.scoreNote)
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func topGapsCard(_ gaps: [ResumeGap]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Top 3 gaps", systemImage: "exclamationmark.triangle.fill")
                .font(.appCaption.weight(.bold))
                .foregroundStyle(AppColors.accentSky)

            ForEach(gaps.prefix(3)) { gap in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Text(gap.severity.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(severityColor(gap.severity))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(severityColor(gap.severity).opacity(0.12), in: Capsule())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(gap.title)
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(gap.explanation)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func missingKeywordsCard(_ diagnosis: ResumeDiagnosis) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Missing keywords", systemImage: "key.fill")
                .font(.appCaption.weight(.bold))
                .foregroundStyle(AppColors.accentTeal)

            if diagnosis.missingKeywords.isEmpty {
                Text("No missing keyword list was returned yet. Review the top gaps and use the job description as the source of truth.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(diagnosis.groupedKeywords, id: \.importance) { group in
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(group.importance.label)
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(AppColors.textTertiary)

                        FlowLayout(spacing: AppSpacing.xs) {
                            ForEach(group.keywords.prefix(8)) { keyword in
                                Text(keyword.keyword)
                                    .font(.appCaption.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 6)
                                    .background(keywordColor(group.importance).opacity(0.12), in: Capsule())
                                    .overlay(Capsule().strokeBorder(keywordColor(group.importance).opacity(0.24), lineWidth: 1))
                            }
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var loadingState: some View {
        ResumeOptimizationLoadingView(mode: .diagnosis)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Start with resume + job", systemImage: "doc.badge.plus")
                .font(.appHeadline)
                .foregroundStyle(AppColors.textPrimary)
            Text("Upload your resume and paste a job description to see what a recruiter may notice in 7 seconds.")
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            GradientButton(title: "Analyze my resume", icon: "wand.and.stars") {
                onEditTargetJob()
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Diagnosis unavailable", systemImage: "exclamationmark.triangle.fill")
                .font(.appHeadline)
                .foregroundStyle(AppColors.accentSky)
            Text(message)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("You can still open the optimized resume and continue improving it.")
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var bottomActions: some View {
        VStack(spacing: AppSpacing.sm) {
            if viewModel.optimizationId?.isEmpty == false {
                GradientButton(title: "Improve my resume", icon: "wand.and.stars") {
                    onImprove()
                }
            }
            Button {
                onEditTargetJob()
            } label: {
                Text("Edit target job")
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .glassCard(cornerRadius: AppRadii.md)
            }
            .buttonStyle(GradientButtonStyle())
        }
        .padding(AppSpacing.lg)
        .background(.ultraThinMaterial.opacity(0.86))
    }

    private func severityColor(_ severity: GapSeverity) -> Color {
        switch severity {
        case .high: return AppColors.accentViolet
        case .medium: return AppColors.accentSky
        case .low: return AppColors.accentTeal
        }
    }

    private func keywordColor(_ importance: KeywordImportance) -> Color {
        switch importance {
        case .high: return AppColors.accentViolet
        case .medium: return AppColors.accentSky
        case .low: return AppColors.accentTeal
        }
    }
}

#Preview {
    NavigationStack {
        ResumeDiagnosisView(
            viewModel: ResumeDiagnosisViewModel(optimizationId: "mock-opt", diagnosis: .sample()),
            onImprove: {},
            onEditTargetJob: {}
        )
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}
