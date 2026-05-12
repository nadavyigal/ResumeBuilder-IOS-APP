import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.hasBootstrappedSession {
                MainTabViewV2()
            } else {
                ProgressView()
                    .tint(Theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bgPrimary.ignoresSafeArea())
            }
        }
        .task(id: appState.hasBootstrappedSession) {
            guard appState.hasBootstrappedSession, appState.isAuthenticated else { return }
            await appState.convertAnonymousSessionIfNeeded()
            await appState.refreshCredits()
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
