import SwiftUI

struct MainTabViewV2: View {
    @State private var selectedTab: ResumlyTab = .tailor

    // Stable VM instances — created once, survive tab switches.
    @State private var tailorViewModel = TailorViewModel()
    @State private var designViewModel = DesignViewModel(optimizationId: nil)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Keep tabs alive to preserve form fields and in-flight async state.
            Group {
                TailorView(viewModel: tailorViewModel, onSwitchTab: switchTab)
                    .opacity(selectedTab == .tailor ? 1 : 0)
                    .allowsHitTesting(selectedTab == .tailor)

                OptimizedResumeTabView(onSwitchTab: switchTab)
                    .opacity(selectedTab == .optimized ? 1 : 0)
                    .allowsHitTesting(selectedTab == .optimized)

                RedesignResumeView(
                    viewModel: designViewModel,
                    onPreview: { selectedTab = .optimized }
                )
                .opacity(selectedTab == .design ? 1 : 0)
                .allowsHitTesting(selectedTab == .design)

                ExpertTabView(onSwitchTab: switchTab)
                    .opacity(selectedTab == .expert ? 1 : 0)
                    .allowsHitTesting(selectedTab == .expert)

                ProfileView()
                    .opacity(selectedTab == .me ? 1 : 0)
                    .allowsHitTesting(selectedTab == .me)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ResumlyTabBar(selection: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .tint(Theme.accent)
    }

    private func switchTab(_ tab: ResumlyTab) {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            selectedTab = tab
        }
    }
}

#Preview {
    MainTabViewV2()
        .environment(AppState())
}
