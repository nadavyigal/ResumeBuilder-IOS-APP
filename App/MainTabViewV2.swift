import SwiftUI

struct MainTabViewV2: View {
    @State private var selectedTab: AppTab = .home

    // Shared state threaded through tabs
    @State private var resumeId: String? = nil
    @State private var jobDescription: String = ""
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
                        onAnalyze: { id, jd in
                            resumeId = id
                            jobDescription = jd
                            selectedTab = .improve
                        }
                    )
                case .improve:
                    ImproveView(
                        viewModel: ImproveViewModel(
                            resumeId: resumeId,
                            jobDescription: jobDescription
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
