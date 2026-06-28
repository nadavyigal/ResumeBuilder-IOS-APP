import SwiftUI

/// Tab-level wrapper for Expert Analysis.
/// Builds a fresh ExpertModesViewModel whenever latestOptimizationId changes.
/// Shows an empty state until an optimization is available.
struct ExpertTabView: View {
    @Environment(AppState.self) private var appState
    var onSwitchTab: (ResumlyTab) -> Void

    @State private var expertVM: ExpertModesViewModel? = nil
    private let trackingService = ApplicationTrackingService()

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
        .task(id: appState.latestOptimizationId) {
            syncVM()
            await linkCurrentOptimizationToApplicationIfAvailable()
        }
        .onChange(of: appState.latestOptimizationId) { syncVM() }
    }

    private func syncVM() {
        guard let id = appState.latestOptimizationId, !id.hasPrefix("mock-") else {
            expertVM = nil
            return
        }
        if expertVM?.optimizationId == id { return }
        expertVM = ExpertModesViewModel(
            optimizationId: id,
            resumeViewModel: OptimizedResumeViewModel(
                optimizationId: id,
                jobURLString: appState.jobURL(for: id)
            )
        )
    }

    private func linkCurrentOptimizationToApplicationIfAvailable() async {
        guard let id = appState.latestOptimizationId,
              !id.hasPrefix("mock-"),
              let token = appState.session?.accessToken,
              let vm = expertVM else {
            return
        }
        do {
            let apps = try await trackingService.listApplications(token: token)
            if let app = apps.first(where: { $0.optimizationId == id || $0.optimizedResumeId == id }) {
                vm.applicationId = app.id
                await vm.loadSavedReports(token: token)
            }
        } catch {
            // Expert can still run without an application link.
        }
    }

    private var noOptimizationView: some View {
        LockedTabTeaser(
            title: "Expert",
            headline: "The full submit package, done for you.",
            previewCaption: "Cover letters & submit packages",
            subtitle: "A tailored cover letter, likely recruiter questions, and an export-ready package for every application.",
            checklist: [
                .init(title: "Upload your résumé", isComplete: appState.hasUploadedResumeThisSession),
                .init(title: "Run Optimize once", isComplete: appState.latestOptimizationId != nil)
            ],
            ctaTitle: "Upload résumé on Home",
            systemImage: "rectangle.stack.badge.person.crop",
            onCTA: { onSwitchTab(.tailor) }
        ) {
            LockedExpertPreview()
        }
    }
}

#Preview {
    ExpertTabView(onSwitchTab: { _ in })
        .environment(AppState())
}
