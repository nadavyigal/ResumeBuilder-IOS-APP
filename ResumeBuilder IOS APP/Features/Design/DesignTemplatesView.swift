import Observation
import SwiftUI

struct DesignTemplatesView: View {
    @Environment(AppState.self) private var appState
    let optimizationId: String
    let snapshot: ResumeSnapshot
    @State private var viewModel = DesignTemplatesViewModel()

    var body: some View {
        List {
            Section("Preview") {
                ResumePreviewCard(snapshot: snapshot, template: viewModel.selectedTemplate)
            }

            Section("Templates") {
                ForEach(viewModel.templates) { template in
                    Button {
                        viewModel.selectedTemplate = template
                    } label: {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                Text(template.description ?? template.category ?? "Resume template")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let atsScore = template.atsScore {
                                    Text("ATS-safe score \(atsScore)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if template.isPremium == true {
                                Text("Premium")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial, in: Capsule())
                            }
                            if viewModel.selectedTemplate?.id == template.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Redesign") {
                TextField("Ask for a style change", text: $viewModel.changeRequest, axis: .vertical)
                Button("Apply Redesign Request") {
                    Task {
                        await viewModel.customize(
                            optimizationId: optimizationId,
                            token: appState.session?.accessToken
                        )
                    }
                }
                .disabled(viewModel.changeRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let message = viewModel.statusMessage {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.load(token: appState.session?.accessToken)
        }
        .navigationTitle("Design Resume")
    }
}

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
