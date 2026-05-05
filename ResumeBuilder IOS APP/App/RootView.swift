import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        MainTabViewV2()
        .task {
            if appState.isAuthenticated {
                await appState.convertAnonymousSessionIfNeeded()
                await appState.refreshCredits()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
