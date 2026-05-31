import SwiftUI

@main
struct ResumeBuilder_IOS_APPApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .task {
                    await appState.bootstrapAndRefreshSession()
                    AnalyticsService.shared.track(.appLaunched(isAuthenticated: appState.isAuthenticated))
                    if !appState.isAuthenticated {
                        AnalyticsService.shared.track(.guestModeStarted)
                    }
                }
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
        }
    }
}
