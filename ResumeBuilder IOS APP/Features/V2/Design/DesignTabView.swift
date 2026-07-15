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
            previewCaption: "12 ATS-safe templates",
            subtitle: "Swap layouts, colors, and fonts. Every template stays parseable by the bots.",
            checklist: [
                .init(title: "Upload your résumé", isComplete: appState.hasUploadedResumeThisSession),
                .init(title: "Run Optimize once", isComplete: appState.latestOptimizationId != nil)
            ],
            ctaTitle: "Upload résumé on Home",
            systemImage: "paintbrush.fill",
            recoveryState: appState.optimizationRecoveryState,
            onRetryRecovery: retryRecovery,
            onCTA: { onSwitchTab(.tailor) }
        ) {
            HStack(spacing: AppSpacing.md) {
                TemplateThumbnail(name: "Modern", category: "modern", templateId: "modern")
                TemplateThumbnail(name: "ATS", category: "traditional", templateId: "ats-safe")
                TemplateThumbnail(name: "Creative", category: "creative", templateId: "creative")
            }
        }
    }

    private func retryRecovery() {
        Task { await appState.reconcileLatestOptimization() }
    }
}

#Preview {
    DesignTabView(viewModel: DesignViewModel(optimizationId: nil), onSwitchTab: { _ in })
        .environment(AppState())
}
