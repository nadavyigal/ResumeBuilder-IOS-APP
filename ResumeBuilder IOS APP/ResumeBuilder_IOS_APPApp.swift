import SwiftUI

@main
struct ResumeBuilder_IOS_APPApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    appState.bootstrap()
                }
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
        }
    }
}
