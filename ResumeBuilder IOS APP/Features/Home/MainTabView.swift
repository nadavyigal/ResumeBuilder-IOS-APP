import SwiftUI

struct MainTabView: View {
    @State private var selection: ResumlyTab = .score

    // ViewModels stored as @State so they survive body re-evaluations
    @State private var scoreVM = ScoreViewModel()
    @State private var tailorVM = TailorViewModel()
    @State private var applicationsVM = ApplicationsViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // All views stay alive to preserve scroll/form state; only visibility changes
            Group {
                ScoreView(viewModel: scoreVM)
                    .opacity(selection == .score ? 1 : 0)
                    .allowsHitTesting(selection == .score)

                TailorView(viewModel: tailorVM)
                    .opacity(selection == .tailor ? 1 : 0)
                    .allowsHitTesting(selection == .tailor)

                DesignHubView()
                    .opacity(selection == .design ? 1 : 0)
                    .allowsHitTesting(selection == .design)

                ApplicationsListView(viewModel: applicationsVM)
                    .opacity(selection == .track ? 1 : 0)
                    .allowsHitTesting(selection == .track)

                ProfileView()
                    .opacity(selection == .profile ? 1 : 0)
                    .allowsHitTesting(selection == .profile)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom floating tab bar
            ResumlyTabBar(selection: $selection)
        }
        .ignoresSafeArea(edges: .bottom)
        .tint(Theme.accent)
    }
}
