#if DEBUG
import SwiftUI

/// Shows the export paywall sheet with sample prices and no StoreKit, so its
/// layout and copy can be checked in a simulator, including Hebrew RTL.
/// The prices are samples for the screenshot; the real sheet shows
/// `product.displayPrice` from the App Store.
///
/// DEBUG only, reached via `--smoke-paywall` (add `--smoke-he` for Hebrew),
/// the same convention as `--smoke-diagnosis`. It ships in no Release build.
struct PaywallSmokeHarness: View {
    @State private var appState = AppState()
    @State private var optimizationId: String? = "smoke-optimization"

    private var wantsHebrew: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-he")
    }

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .sheet(item: Binding(
                get: { optimizationId.map(SmokeItem.init) },
                set: { optimizationId = $0?.id }
            )) { item in
                ExportPaywallSheet(
                    optimizationId: item.id,
                    model: ExportPaywallModel(optimizationId: item.id, fixtureOffers: [
                        PackOffer(id: "resumely.exports.14", credits: 14, displayPrice: "$7.99"),
                        PackOffer(id: "resumely.exports.5.v2", credits: 5, displayPrice: "$3.99"),
                    ]),
                    onUnlocked: {},
                    onClose: { optimizationId = nil }
                )
            }
            .environment(appState)
            .onAppear {
                if wantsHebrew { LocalizationManager.shared.setLanguage(.hebrew) }
            }
    }

    private struct SmokeItem: Identifiable {
        let id: String
    }
}
#endif
