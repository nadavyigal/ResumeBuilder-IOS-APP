import SwiftUI

@main
struct ResumeBuilder_IOS_APPApp: App {
    @State private var appState = AppState()
    @State private var localization = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
#if DEBUG
            // Renders the fit-journey diagnosis with fixture data so the screen
            // can be looked at without an account and a real optimization.
            // Follows the existing --smoke-* launch-argument convention.
            if ProcessInfo.processInfo.arguments.contains("--smoke-diagnosis") {
                DiagnosisSmokeHarness()
                    .environment(localization)
                    .environment(\.locale, localization.locale)
                    .environment(\.layoutDirection, localization.layoutDirection)
                    .preferredColorScheme(.dark)
            } else {
                appBody
            }
#else
            appBody
#endif
        }
    }

    @ViewBuilder
    private var appBody: some View {
            ContentView()
                .environment(appState)
                .environment(localization)
                .environment(\.locale, localization.locale)
                .environment(\.layoutDirection, localization.layoutDirection)
                .preferredColorScheme(.dark)
                .task {
                    // Warns when both internal-tester allowlists are empty, which
                    // silently counts every team install as a real user.
                    AnalyticsService.assertInternalTesterConfigIsUsable()
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
