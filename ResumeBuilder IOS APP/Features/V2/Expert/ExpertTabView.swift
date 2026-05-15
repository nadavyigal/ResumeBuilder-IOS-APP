import SwiftUI

/// Tab-level wrapper for Expert Analysis.
/// Builds a fresh ExpertModesViewModel whenever latestOptimizationId changes.
/// Shows an empty state until an optimization is available.
struct ExpertTabView: View {
    @Environment(AppState.self) private var appState
    var onSwitchTab: (ResumlyTab) -> Void

    @State private var expertVM: ExpertModesViewModel? = nil

    var body: some View {
        Group {
            if let vm = expertVM {
                NavigationStack {
                    ExpertModesView(vm: vm)
                }
            } else {
                noOptimizationView
            }
        }
        .onAppear { syncVM() }
        .onChange(of: appState.latestOptimizationId) { syncVM() }
    }

    private func syncVM() {
        guard let id = appState.latestOptimizationId else {
            expertVM = nil
            return
        }
        if expertVM?.optimizationId == id { return }
        expertVM = ExpertModesViewModel(
            optimizationId: id,
            resumeViewModel: OptimizedResumeViewModel(optimizationId: id)
        )
    }

    private var noOptimizationView: some View {
        ContentUnavailableView {
            Label("No expert analysis yet", systemImage: "rectangle.stack.badge.person.crop")
        } description: {
            Text("Run Optimize in the Tailor tab to unlock expert workflows.")
        } actions: {
            Button("Go to Tailor") { onSwitchTab(.tailor) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .foregroundStyle(Theme.textPrimary)
        .screenBackground(showRadialGlow: false)
    }
}

#Preview {
    ExpertTabView(onSwitchTab: { _ in })
        .environment(AppState())
}
