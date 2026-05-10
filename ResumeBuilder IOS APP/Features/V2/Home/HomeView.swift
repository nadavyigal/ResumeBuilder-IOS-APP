import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: HomeViewModel
    var onContinueOptimize: ((AppTab) -> Void)? = nil

    @State private var showATSBreakdown = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Header
                GreetingHeader(
                    name: firstName,
                    screenTitle: "Dashboard"
                )
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)

                // Hero score card
                heroCard

                // 4 Metric tiles
                metricsGrid

                // Continue editing
                if !viewModel.recentExports.isEmpty {
                    continueEditingCard
                }

                // Recent exports
                if !viewModel.recentExports.isEmpty {
                    recentExportsList
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .screenBackground(showRadialGlow: true)
        .task(id: appState.session?.accessToken) { await viewModel.load(token: appState.session?.accessToken) }
        .sheet(isPresented: $showATSBreakdown) {
            NavigationStack {
                ATSBreakdownView(
                    analysis: ResumeAnalysis.dashboard(
                        overall: viewModel.overallScore,
                        keywordScore: viewModel.keywordScore,
                        content: viewModel.contentScore,
                        design: viewModel.designScore
                    ),
                    showsDismissButton: true
                )
            }
        }
    }

    // MARK: - Subviews

    private var heroCard: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: AppSpacing.xl) {
                ScoreRingView(score: viewModel.overallScore, size: 160)

                VStack(spacing: AppSpacing.xs) {
                    Text("Resume Health Score")
                        .font(.appHeadline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text(scoreLabel)
                        .font(.appBody)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(AppSpacing.xxl)
            .frame(maxWidth: .infinity)
            .glassCard()
            .padding(.horizontal, AppSpacing.lg)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onTapGesture { showATSBreakdown = true }
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the ATS breakdown pillars.")
            .accessibilityAddTraits(.isButton)

            WaveDecorationView()
                .allowsHitTesting(false)
                .padding(.horizontal, AppSpacing.lg + AppSpacing.xl)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
            MetricCard(icon: "doc.text.magnifyingglass", label: "ATS Match", value: "\(viewModel.overallScore)%", subtitle: "Keyword alignment", accentColor: AppColors.accentTeal)
            MetricCard(icon: "pencil.and.list.clipboard", label: "Content", value: metricValue(viewModel.contentScore), subtitle: "Clarity & impact", accentColor: AppColors.accentViolet)
            MetricCard(icon: "paintbrush.pointed", label: "Design", value: metricValue(viewModel.designScore), subtitle: "Visual appeal", accentColor: AppColors.accentSky)
            MetricCard(icon: "key.fill", label: "Keywords", value: metricValue(viewModel.keywordScore), subtitle: "Missing terms", accentColor: AppColors.accentTeal)
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var continueEditingCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Continue Editing")
                .font(.appHeadline)
                .foregroundStyle(AppColors.textPrimary)

            if let latest = viewModel.recentExports.first {
                ResumeFileCard(
                    filename: latest.filename,
                    metadata: latest.formattedDate
                )
            }

            HStack(spacing: AppSpacing.md) {
                GradientButton(title: "Optimize") { onContinueOptimize?(.improve) }
                GradientButton(title: "Redesign") { onContinueOptimize?(.design) }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private var recentExportsList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Recent Exports")
                .font(.appHeadline)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.lg)

            ForEach(viewModel.recentExports) { export in
                ResumeFileCard(
                    filename: export.filename,
                    metadata: "\(export.kind.rawValue.capitalized) · \(export.formattedDate)"
                )
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    // MARK: - Helpers

    private var firstName: String {
        guard let email = appState.session?.email,
              let local = email.components(separatedBy: "@").first else { return "there" }
        return local.capitalized
    }

    private var scoreLabel: String {
        switch viewModel.overallScore {
        case 80...100: return "Excellent — ready to apply"
        case 60..<80:  return "Good — a few improvements left"
        default:       return "Needs work — let's improve it"
        }
    }

    private func metricValue(_ score: Int?) -> String {
        guard let score else { return "–" }
        return "\(score)%"
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel(exportsService: MockRecentExportsService()))
        .environment(AppState())
}
