import SwiftUI

// Legacy tab view — superseded by MainTabViewV2 which is the active root.
struct MainTabView: View {
    @State private var tailorViewModel = TailorViewModel()

    var body: some View {
        TabView {
            TailorView(viewModel: tailorViewModel)
                .tabItem {
                    Label("Tailor", systemImage: "wand.and.stars")
                }

            ProfileView()
                .tabItem {
                    Label("Me", systemImage: "person.crop.circle")
                }
        }
    }
}
