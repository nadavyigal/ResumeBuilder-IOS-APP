import SwiftUI

// Legacy tab view — superseded by MainTabViewV2 which is the active root.
struct MainTabView: View {
    @State private var tailorViewModel = TailorViewModel()
    @State private var applicationsViewModel = ApplicationsViewModel()

    var body: some View {
        TabView {
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
