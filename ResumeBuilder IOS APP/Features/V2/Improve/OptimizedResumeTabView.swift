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
            if let vm = optimizedVM {
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
        optimizedVM = OptimizedResumeViewModel(optimizationId: id)
    }

    private var noOptimizationView: some View {
        LockedTabTeaser(
            title: "Optimized",
            headline: "Here's what you'll unlock.",
            previewCaption: "Your résumé, scored & rewritten",
            subtitle: "An ATS match score, keyword gaps, and line-by-line fixes — tuned to your target job.",
            checklist: [
                .init(title: "Upload your résumé", isComplete: appState.latestOptimizationId != nil),
                .init(title: "Add a job to match against", isComplete: appState.latestOptimizationId != nil)
            ],
            ctaTitle: "Upload résumé on Home",
            systemImage: "wand.and.stars",
            onCTA: { onSwitchTab(.tailor) }
        ) {
            LockedScorePreview()
        }
    }
}

#Preview {
    OptimizedResumeTabView(onSwitchTab: { _ in })
        .environment(AppState())
}
