import SwiftUI

/// Tab-level wrapper for Design — locked until an optimization exists.
struct DesignTabView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: DesignViewModel
    var isActive = true
    var onSwitchTab: (ResumlyTab) -> Void
    var onPreview: (() -> Void)? = nil

    var body: some View {
        Group {
            if appState.latestOptimizationId != nil {
                RedesignResumeView(viewModel: viewModel, isActive: isActive, onPreview: onPreview)
            } else {
                lockedView
            }
        }
    }

    private var lockedView: some View {
        LockedTabTeaser(
            title: "Design",
            headline: "Recruiter-ready templates, one tap.",
            subtitle: "12 ATS-friendly templates. Swap layouts, colors, and fonts — every one stays simple to parse.",
            checklist: [
                .init(title: "Upload your résumé", isComplete: appState.hasUploadedResumeThisSession),
                .init(title: "Run Optimize once", isComplete: appState.latestOptimizationId != nil)
            ],
            ctaTitle: "Upload résumé on Home",
            systemImage: "paintbrush.fill",
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
    DesignTabView(viewModel: DesignViewModel(optimizationId: nil), onSwitchTab: { _ in })
        .environment(AppState())
}
