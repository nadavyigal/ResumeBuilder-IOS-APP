import SwiftUI

struct MainTabViewV2: View {
    @State private var selectedTab: ResumlyTab = .score

    // Stable VM instances — created once and never recreated on re-render.
    // This prevents duplicate network fetches and preserves in-flight async state.
    @State private var scoreViewModel = ScoreViewModel()
    @State private var tailorViewModel = TailorViewModel()
    @State private var designViewModel = DesignViewModel(optimizationId: nil)
    @State private var applicationsViewModel = ApplicationsViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Keep tabs alive to preserve form fields and in-flight async state.
            Group {
                ScoreView(viewModel: scoreViewModel)
                    .opacity(selectedTab == .score ? 1 : 0)
                    .allowsHitTesting(selectedTab == .score)

                TailorView(viewModel: tailorViewModel)
                    .opacity(selectedTab == .tailor ? 1 : 0)
                    .allowsHitTesting(selectedTab == .tailor)

                RedesignResumeView(
                    viewModel: designViewModel,
                    onPreview: { selectedTab = .profile }
                )
                .opacity(selectedTab == .design ? 1 : 0)
                .allowsHitTesting(selectedTab == .design)

                ApplicationsListView(viewModel: applicationsViewModel)
                    .opacity(selectedTab == .track ? 1 : 0)
                    .allowsHitTesting(selectedTab == .track)

                ProfileView()
                    .opacity(selectedTab == .profile ? 1 : 0)
                    .allowsHitTesting(selectedTab == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ResumlyTabBar(selection: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .tint(Theme.accent)
    }
}

#Preview {
    MainTabViewV2()
        .environment(AppState())
}
