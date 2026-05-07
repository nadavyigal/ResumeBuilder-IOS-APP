import SwiftUI

struct ApplicationDetailView: View {
    let application: ApplicationItem

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            List {
                Section {
                    DetailRow(label: "Role",    value: application.jobTitle ?? "-")
                    DetailRow(label: "Company", value: application.companyName ?? "-")
                    DetailRow(label: "Applied", value: application.appliedDate ?? "-")
                    DetailRow(label: "Status",  value: application.status ?? "applied")
                    if let score = application.atsScore {
                        DetailRow(label: "ATS Score", value: "\(score)")
                    }
                    if let url = application.sourceURL {
                        DetailRow(label: "Source", value: url)
                    }
                } header: {
                    Text("Details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .textCase(nil)
                }
                .listRowBackground(Theme.bgCard)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.bgPrimary)
        }
        .navigationTitle("Application")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct OptimizationDetailView: View {
    let optimization: OptimizationItem

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ResumePreviewCard(
                        snapshot: ResumeSnapshot(
                            id: optimization.id,
                            title: optimization.jobTitle ?? "Optimized Resume",
                            subtitle: optimization.company ?? optimization.jobURL ?? "Saved resume",
                            matchScore: optimization.matchScore,
                            json: optimization.rewriteData
                        )
                    )

                    // ── Meta ──────────────────────────────────────────────────
                    VStack(spacing: 1) {
                        if let template = optimization.templateKey {
                            MetaRow(label: "Template", value: template)
                        }
                        if let status = optimization.status {
                            MetaRow(label: "Status", value: status)
                        }
                        if let url = optimization.jobURL {
                            MetaRow(label: "Job URL", value: url)
                        }
                    }
                    .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))

                    // ── Redesign CTA ──────────────────────────────────────────
                    NavigationLink {
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
                    } label: {
                        Text("Redesign Resume")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(.white)
                            .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle("Optimized Resume")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Shared row components

private struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}

private struct MetaRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
