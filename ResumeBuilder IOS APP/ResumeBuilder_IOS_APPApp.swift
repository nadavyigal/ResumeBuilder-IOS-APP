import SwiftUI

@main
struct ResumeBuilder_IOS_APPApp: App {
    @State private var appState = AppState()
    @State private var localization = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(localization)
                .environment(\.locale, localization.locale)
                .environment(\.layoutDirection, localization.layoutDirection)
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
