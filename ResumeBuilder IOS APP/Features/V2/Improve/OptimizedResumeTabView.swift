import SwiftUI

/// Tab-level wrapper for the Optimized Resume screen.
/// Builds a fresh OptimizedResumeViewModel whenever latestOptimizationId changes.
/// Shows an empty state until an optimization exists in AppState.
struct OptimizedResumeTabView: View {
    @Environment(AppState.self) private var appState
    var isActive = true
    var onSwitchTab: (ResumlyTab) -> Void

    @State private var optimizedVM: OptimizedResumeViewModel? = nil

    var body: some View {
        Group {
            // The identifier check is load-bearing, not defensive. `optimizedVM`
            // is @State and only re-syncs on an `onChange`, so during the swap
            // to a freshly applied optimization the previous view model is still
            // held here. When the tab activates in that window the old view
            // renders and reports itself seen, which is how `optimized_viewed`
            // and `export_cta_seen` came to fire twice with the previous
            // optimization's id (device, 1.4.9, 2026-08-12). Rendering only the
            // view model that matches AppState removes the stale view from the
            // hierarchy before it can be activated.
            if let vm = optimizedVM, vm.optimizationIdentifier == appState.latestOptimizationId {
                NavigationStack {
                    OptimizedResumeView(viewModel: vm, isActive: isActive, onSwitchTab: onSwitchTab)
                        .id(vm.optimizationIdentifier)
                }
            } else {
                noOptimizationView
            }
        }
        .onAppear { syncVM() }
        .onChange(of: appState.latestOptimizationId) {
            syncVM()
        }
        .onChange(of: appState.resumeSectionsNeedRefresh) { _, needsRefresh in
            guard needsRefresh else { return }
            appState.resumeSectionsNeedRefresh = false
            Task { await optimizedVM?.forceReloadSections(appState: appState) }
        }
    }

    private func syncVM() {
        guard let id = appState.latestOptimizationId else {
            optimizedVM = nil
            return
        }
        if optimizedVM?.optimizationIdentifier == id {
            return
        }
        optimizedVM = OptimizedResumeViewModel(
            optimizationId: id,
            jobURLString: appState.jobURL(for: id)
        )
    }

    private var noOptimizationView: some View {
        LockedTabTeaser(
            title: "Optimized",
            headline: "Here's what you'll unlock.",
            subtitle: "A Resumely Match Score, keyword gaps, and line-by-line fixes — tuned to one target job.",
            checklist: [
                .init(title: "Upload your résumé", isComplete: appState.hasUploadedResumeThisSession),
                .init(title: "Add a job to match against", isComplete: appState.hasAddedJobThisSession)
            ],
            ctaTitle: "Upload résumé on Home",
            systemImage: "wand.and.stars",
            recoveryState: appState.optimizationRecoveryState,
            onRetryRecovery: retryRecovery,
            onCTA: { onSwitchTab(.tailor) }
        )
    }

    private func retryRecovery() {
        Task { await appState.reconcileLatestOptimization() }
    }
}

#Preview {
    OptimizedResumeTabView(onSwitchTab: { _ in })
        .environment(AppState())
}
