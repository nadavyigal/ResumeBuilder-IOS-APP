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
        ContentUnavailableView {
            Label("No optimized resume yet", systemImage: "wand.and.stars")
        } description: {
            Text("Upload and optimize on Home to see your resume here.")
        } actions: {
            Button("Go to Home") { onSwitchTab(.tailor) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .foregroundStyle(Theme.textPrimary)
        .screenBackground(showRadialGlow: false)
    }
}

#Preview {
    OptimizedResumeTabView(onSwitchTab: { _ in })
        .environment(AppState())
}
