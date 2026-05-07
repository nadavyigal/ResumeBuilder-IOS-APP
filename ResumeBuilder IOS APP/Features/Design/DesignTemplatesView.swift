import Observation
import SwiftUI

struct DesignTemplatesView: View {
    @Environment(AppState.self) private var appState
    let optimizationId: String
    let snapshot: ResumeSnapshot
    @State private var viewModel = DesignTemplatesViewModel()

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(Theme.accent)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // ── Preview card ──────────────────────────────────────
                        ResumePreviewCard(snapshot: snapshot, template: viewModel.selectedTemplate)

                        // ── Templates ─────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Templates")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textTertiary)
                                .textCase(nil)

                            VStack(spacing: 1) {
                                ForEach(viewModel.templates) { template in
                                    Button {
                                        viewModel.selectedTemplate = template
                                    } label: {
                                        HStack(alignment: .top, spacing: 12) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(template.name)
                                                    .font(.body.weight(.medium))
                                                    .foregroundStyle(Theme.textPrimary)
                                                Text(template.description ?? template.category ?? "Resume template")
                                                    .font(.subheadline)
                                                    .foregroundStyle(Theme.textSecondary)
                                                if let atsScore = template.atsScore {
                                                    Text("ATS-safe: \(atsScore)")
                                                        .font(.caption)
                                                        .foregroundStyle(Theme.accentCyan)
                                                }
                                            }

                                            Spacer()

                                            HStack(spacing: 8) {
                                                if template.isPremium == true {
                                                    Text("Pro")
                                                        .font(.caption.bold())
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3)
                                                        .foregroundStyle(Theme.accent)
                                                        .background(Theme.accent.opacity(0.15), in: Capsule())
                                                }
                                                if viewModel.selectedTemplate?.id == template.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(Theme.accent)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            viewModel.selectedTemplate?.id == template.id
                                                ? Theme.accent.opacity(0.08)
                                                : Theme.bgCard
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                        }

                        // ── Style request ─────────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Style Request")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textTertiary)

                            ZStack(alignment: .topLeading) {
                                Theme.bgCard
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusBadge, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.radiusBadge, style: .continuous)
                                            .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
                                    )

                                if viewModel.changeRequest.isEmpty {
                                    Text("Ask for a style change, e.g. \"more modern\"")
                                        .foregroundStyle(Theme.textTertiary)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 16)
                                }

                                TextEditor(text: $viewModel.changeRequest)
                                    .scrollContentBackground(.hidden)
                                    .background(.clear)
                                    .frame(minHeight: 90)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(Theme.textPrimary)
                                    .tint(Theme.accent)
                            }
                            .frame(minHeight: 90)

                            Button {
                                Task {
                                    await viewModel.customize(
                                        optimizationId: optimizationId,
                                        token: appState.session?.accessToken
                                    )
                                }
                            } label: {
                                Text("Apply Redesign Request")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .foregroundStyle(.white)
                                    .background(
                                        viewModel.changeRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                            ? Theme.textTertiary
                                            : Theme.accent,
                                        in: RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous)
                                    )
                            }
                            .disabled(viewModel.changeRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        // ── Status ────────────────────────────────────────────
                        if let message = viewModel.statusMessage {
                            Label(message, systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .navigationTitle("Design Resume")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await viewModel.load(token: appState.session?.accessToken)
        }
    }
}

// MARK: - ViewModel (unchanged logic, just extracted)

@Observable
@MainActor
final class DesignTemplatesViewModel {
    var templates: [DesignTemplate] = []
    var selectedTemplate: DesignTemplate?
    var changeRequest = ""
    var isLoading = false
    var statusMessage: String?

    private let apiClient = APIClient()

    func load(token: String?) async {
        guard let token else {
            statusMessage = "Please sign in to load templates."
            return
        }
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        do {
            let response: DesignTemplatesResponse = try await apiClient.get(endpoint: .designTemplates, token: token)
            templates = response.templates
            selectedTemplate = templates.first
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func customize(optimizationId: String, token: String?) async {
        guard let token else {
            statusMessage = "Please sign in to redesign."
            return
        }

        struct CustomizeRequest: Encodable {
            let changeRequest: String
        }

        do {
            let _: APIStatusResponse = try await apiClient.postCodable(
                endpoint: .customizeDesign(optimizationId),
                body: CustomizeRequest(changeRequest: changeRequest),
                token: token
            )
            statusMessage = "Redesign request saved. Refresh the web preview if you need export-ready output."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
