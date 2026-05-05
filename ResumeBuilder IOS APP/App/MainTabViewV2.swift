import SwiftUI

struct MainTabViewV2: View {
    @State private var selectedTab: AppTab = .home

    // Shared state threaded through tabs
    @State private var resumeId: String? = nil
    @State private var jobDescriptionId: String? = nil
    @State private var jobDescription: String = ""
    @State private var jobDescriptionURL: String = ""
    @State private var initialAnalysis: ResumeAnalysis? = nil
    @State private var initialImprovements: [ResumeImprovement] = []
    @State private var analysis: ResumeAnalysis? = nil
    @State private var optimizationId: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(
                        viewModel: HomeViewModel(),
                        onContinueOptimize: { tab in selectedTab = tab }
                    )
                case .scan:
                    ScanResumeView(
                        viewModel: ScanViewModel(),
                        onAnalyze: { input in
                            resumeId = input.resumeId
                            jobDescriptionId = input.jobDescriptionId
                            jobDescription = input.jobDescription
                            jobDescriptionURL = input.jobDescriptionURL
                            if let score = input.initialScore {
                                initialAnalysis = ResumeAnalysis(
                                    overall: score,
                                    ats: score,
                                    content: 0,
                                    design: 0,
                                    missingKeywords: input.missingKeywords
                                )
                            }
                            initialImprovements = input.keyImprovements.enumerated().map { index, improvement in
                                ResumeImprovement(
                                    id: "upload-improvement-\(index)",
                                    title: improvement,
                                    description: "Recommended by the optimizer for this job.",
                                    impact: index == 0 ? "high" : "medium"
                                )
                            }
                            selectedTab = .improve
                        }
                    )
                case .improve:
                    ImproveView(
                        viewModel: ImproveViewModel(
                            resumeId: resumeId,
                            jobDescriptionId: jobDescriptionId,
                            jobDescription: jobDescription,
                            jobDescriptionURL: jobDescriptionURL,
                            initialAnalysis: initialAnalysis,
                            initialImprovements: initialImprovements
                        ),
                        onOptimized: { optId in
                            optimizationId = optId
                            selectedTab = .design
                        }
                    )
                case .design:
                    RedesignResumeView(
                        viewModel: DesignViewModel(optimizationId: optimizationId),
                        onPreview: { selectedTab = .profile }
                    )
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
