import SwiftUI

struct MainTabView: View {
    @State private var scoreViewModel = ScoreViewModel()
    @State private var tailorViewModel = TailorViewModel()
    @State private var applicationsViewModel = ApplicationsViewModel()

    var body: some View {
        TabView {
            ScoreView(viewModel: scoreViewModel)
                .tabItem {
                    Label("Score", systemImage: "gauge.medium")
                }

            TailorView(viewModel: tailorViewModel)
                .tabItem {
                    Label("Tailor", systemImage: "wand.and.stars")
                }

            ApplicationsListView(viewModel: applicationsViewModel)
                .tabItem {
                    Label("Track", systemImage: "tray.full")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }
}
