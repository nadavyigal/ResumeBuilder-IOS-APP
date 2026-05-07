import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView(viewModel: OnboardingViewModel(appState: appState))
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
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
