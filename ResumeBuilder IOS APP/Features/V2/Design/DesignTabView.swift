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
            subtitle: "Choose a layout with clear headings. Change the colors and fonts any time.",
            checklist: [
                .init(title: "Upload your résumé", isComplete: appState.hasUploadedResumeThisSession),
                .init(title: "Check it against a job", isComplete: appState.latestOptimizationId != nil)
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
