import SwiftUI

struct ApplicationDetailView: View {
    let application: ApplicationItem

    var body: some View {
        List {
            LabeledContent("Role", value: application.jobTitle ?? "-")
            LabeledContent("Company", value: application.companyName ?? "-")
            LabeledContent("Applied", value: application.appliedDate ?? "-")
            LabeledContent("Status", value: application.status ?? "applied")
            if let atsScore = application.atsScore {
                LabeledContent("ATS Score", value: "\(atsScore)")
            }
            if let sourceURL = application.sourceURL {
                LabeledContent("Source", value: sourceURL)
            }
            if let optimizationId = application.optimizationId {
                LabeledContent("Optimization", value: optimizationId)
            }
        }
        .navigationTitle("Application")
    }
}

struct OptimizationDetailView: View {
    let optimization: OptimizationItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ResumePreviewCard(
                    snapshot: ResumeSnapshot(
                        id: optimization.id,
                        title: optimization.jobTitle ?? "Optimized Resume",
                        subtitle: optimization.company ?? optimization.jobURL ?? "Saved resume",
                        matchScore: optimization.matchScore,
                        json: optimization.rewriteData
                    )
                )

                if let templateKey = optimization.templateKey {
                    LabeledContent("Template", value: templateKey)
                }
                if let status = optimization.status {
                    LabeledContent("Status", value: status)
                }
                if let jobURL = optimization.jobURL {
                    LabeledContent("Job URL", value: jobURL)
                }

                NavigationLink("Redesign Resume") {
                    DesignTemplatesView(
                        optimizationId: optimization.id,
                        snapshot: ResumeSnapshot(
                            id: optimization.id,
                            title: optimization.jobTitle ?? "Optimized Resume",
                            subtitle: optimization.company ?? "Saved resume",
                            matchScore: optimization.matchScore,
                            json: optimization.rewriteData
                        )
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Optimized Resume")
    }
}
