import SwiftUI

struct MainTabViewV2: View {
    @State private var selectedTab: AppTab = .home

    // Stable VM instances — created once and never recreated on re-render.
    // This prevents duplicate network fetches and preserves in-flight async state.
    @State private var homeViewModel = HomeViewModel()
    @State private var scanViewModel = ScanViewModel()
    @State private var improveViewModel = ImproveViewModel(
        resumeId: nil, jobDescriptionId: nil, jobDescription: "", jobDescriptionURL: ""
    )
    @State private var designViewModel = DesignViewModel(optimizationId: nil)
    @State private var historyViewModel = HistoryViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(
                        viewModel: homeViewModel,
                        onContinueOptimize: { tab in selectedTab = tab }
                    )
                case .scan:
                    ScanResumeView(
                        viewModel: scanViewModel,
                        onAnalyze: { input in
                            let initialAnalysis: ResumeAnalysis? = input.initialScore.map { score in
                                ResumeAnalysis(
                                    overall: score,
                                    ats: score,
                                    content: 0,
                                    design: 0,
                                    missingKeywords: input.missingKeywords
                                )
                            }
                            let initialImprovements = input.keyImprovements.enumerated().map { index, improvement in
                                ResumeImprovement(
                                    id: "upload-improvement-\(index)",
                                    title: improvement,
                                    description: "Recommended by the optimizer for this job.",
                                    impact: index == 0 ? "high" : "medium"
                                )
                            }
                            improveViewModel.configure(
                                resumeId: input.resumeId,
                                jobDescriptionId: input.jobDescriptionId,
                                jobDescription: input.jobDescription,
                                jobDescriptionURL: input.jobDescriptionURL,
                                initialAnalysis: initialAnalysis,
                                initialImprovements: initialImprovements
                            )
                            selectedTab = .improve
                        }
                    )
                case .improve:
                    ImproveView(
                        viewModel: improveViewModel,
                        onOptimized: { optId in
                            designViewModel.setOptimizationId(optId)
                            selectedTab = .design
                        }
                    )
                case .design:
                    RedesignResumeView(
                        viewModel: designViewModel,
                        onPreview: { selectedTab = .profile }
                    )
                case .history:
                    HistoryView(viewModel: historyViewModel)
                case .profile:
                    ProfileViewV2()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    MainTabViewV2()
        .environment(AppState())
}
