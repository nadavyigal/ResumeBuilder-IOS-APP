import SwiftUI

/// Tab-level wrapper for the Optimized Resume screen.
/// Shows an empty state until an optimization exists in AppState.
/// Story 2 replaces the placeholder body with the real preview content.
struct OptimizedResumeTabView: View {
    @Environment(AppState.self) private var appState
    var onSwitchTab: (ResumlyTab) -> Void

    var body: some View {
        if let optimizationId = appState.latestOptimizationId {
            OptimizedResumePlaceholder(optimizationId: optimizationId, onSwitchTab: onSwitchTab)
        } else {
            noOptimizationView
        }
    }

    private var noOptimizationView: some View {
        ContentUnavailableView {
            Label("No optimized resume yet", systemImage: "wand.and.stars")
        } description: {
            Text("Tailor a resume in the Tailor tab to see it here.")
        } actions: {
            Button("Go to Tailor") { onSwitchTab(.tailor) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
        .foregroundStyle(Theme.textPrimary)
        .screenBackground(showRadialGlow: false)
    }
}

/// Placeholder shown in Story 1 when an optimization ID is available.
/// Replaced in Story 2 by the full resume preview.
private struct OptimizedResumePlaceholder: View {
    let optimizationId: String
    var onSwitchTab: (ResumlyTab) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent)
            Text("Optimization ready")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("ID: \(optimizationId)")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground(showRadialGlow: false)
    }
}

#Preview {
    OptimizedResumeTabView(onSwitchTab: { _ in })
        .environment(AppState())
}
