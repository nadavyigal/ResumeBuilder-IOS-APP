import SwiftUI

/// Tab-level wrapper for Design — locked until an optimization exists.
struct DesignTabView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: DesignViewModel
    var onSwitchTab: (ResumlyTab) -> Void
    var onPreview: (() -> Void)? = nil

    var body: some View {
        Group {
            if appState.latestOptimizationId != nil {
                RedesignResumeView(viewModel: viewModel, onPreview: onPreview)
            } else {
                lockedView
            }
        }
    }

    private var lockedView: some View {
        ContentUnavailableView {
            Label("Design unlocks after optimization", systemImage: "paintbrush.fill")
        } description: {
            Text("Upload your resume and run Optimize on Home to style your PDF.")
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
    DesignTabView(viewModel: DesignViewModel(optimizationId: nil), onSwitchTab: { _ in })
        .environment(AppState())
}
