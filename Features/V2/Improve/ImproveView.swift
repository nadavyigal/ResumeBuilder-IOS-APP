import SwiftUI

struct ImproveView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ImproveViewModel
    var onOptimized: ((String) -> Void)? = nil

    @State private var navigateToOptimized = false
    @State private var optimizedSections: [OptimizedResumeSection] = []
    @State private var currentOptId: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    GreetingHeader(name: "there", screenTitle: "Improve")
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.xl)

                    // Score hero
                    scoreHero

                    // 4 metric tiles
                    if let analysis = viewModel.analysis {
                        metricsGrid(analysis: analysis)
                    }

                    // Top fixes
                    if !viewModel.improvements.isEmpty {
                        topFixesList
                    }

                    // Optimize CTA
                    GradientButton(
                        title: viewModel.isOptimizing ? "Optimizing…" : "Optimize for This Job",
                        icon: viewModel.isOptimizing ? nil : "wand.and.stars",
                        isLoading: viewModel.isOptimizing
                    ) {
                        Task {
                            if let optId = await viewModel.optimize(token: appState.session?.accessToken) {
                                currentOptId = optId
                                navigateToOptimized = true
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.appCaption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, AppSpacing.lg)
                    }

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)
            .screenBackground(showRadialGlow: true)
            .navigationDestination(isPresented: $navigateToOptimized) {
                OptimizedResumeView(
                    viewModel: OptimizedResumeViewModel(
                        optimizationId: currentOptId,
                        sections: optimizedSections
                    )
                )
            }
            .task { await viewModel.loadAnalysis(token: appState.session?.accessToken) }
        }
    }

    // MARK: - Subviews

    private var scoreHero: some View {
        VStack(spacing: AppSpacing.lg) {
            if viewModel.isLoading {
                ProgressView()
                    .tint(AppColors.accentViolet)
                    .frame(height: 180)
            } else {
                ScoreRingView(score: viewModel.analysis?.overall ?? 0, size: 160)
            }

            if let keywords = viewModel.analysis?.missingKeywords, !keywords.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Text("Missing Keywords")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(keywords.prefix(6), id: \.self) { kw in
                                Text(kw)
                                    .font(.appCaption)
                                    .foregroundStyle(AppColors.accentViolet)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 4)
                                    .background(AppColors.accentViolet.opacity(0.12), in: Capsule())
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                }
            }
        }
        .padding(AppSpacing.xxl)
        .frame(maxWidth: .infinity)
        .glassCard()
        .padding(.horizontal, AppSpacing.lg)
    }

    private func metricsGrid(analysis: ResumeAnalysis) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
            MetricCard(icon: "doc.text.magnifyingglass", label: "ATS Score", value: "\(analysis.ats)", subtitle: "Keyword alignment", accentColor: AppColors.accentTeal)
            MetricCard(icon: "pencil.and.list.clipboard", label: "Content", value: "\(analysis.content)", subtitle: "Clarity & impact", accentColor: AppColors.accentViolet)
            MetricCard(icon: "paintbrush.pointed", label: "Design", value: "\(analysis.design)", subtitle: "Visual layout", accentColor: AppColors.accentSky)
            MetricCard(icon: "key.fill", label: "Keywords", value: "\(analysis.missingKeywords.count)", subtitle: "Missing terms", accentColor: AppColors.accentTeal)
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var topFixesList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Top Fixes")
                .font(.appHeadline)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.lg)

            ForEach(viewModel.improvements.prefix(4)) { fix in
                FixItemRow(
                    title: fix.title,
                    description: fix.description,
                    impact: fix.impactLevel
                )
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }
}

#Preview {
    ImproveView(
        viewModel: ImproveViewModel(
            resumeId: "test-id",
            jobDescription: "Sample job description",
            analysisService: MockResumeAnalysisService(),
            optimizationService: MockResumeOptimizationService()
        )
    )
    .environment(AppState())
}
