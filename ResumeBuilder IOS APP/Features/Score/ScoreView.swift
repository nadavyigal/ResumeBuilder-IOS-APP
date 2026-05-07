import SwiftUI
import UniformTypeIdentifiers

struct ScoreView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ScoreViewModel
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Score")
                        .font(.largeTitle.bold())

                    Text("Free ATS check")
                        .font(.headline)

                    Text("Upload your resume PDF and paste a LinkedIn/job link. Full optimization unlocks after sign-in.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        isImporterPresented = true
                    } label: {
                        Label(
                            viewModel.selectedResumeName ?? "Choose Resume PDF",
                            systemImage: "doc.badge.plus"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    TextField("LinkedIn or job post URL", text: $viewModel.jobDescriptionURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textFieldStyle(.roundedBorder)

                    TextEditor(text: $viewModel.jobDescription)
                        .frame(minHeight: 180)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topLeading) {
                            if viewModel.jobDescription.isEmpty {
                                Text("Or paste the full job description")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 16)
                            }
                        }

                    Button {
                        Task { await viewModel.runScore(appState: appState) }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Run ATS Score")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let result = viewModel.result {
                        ScoreResultView(result: result, isAuthenticated: appState.isAuthenticated)
                    }
                }
                .padding()
            }
            .navigationTitle("Score")
            .onAppear {
                viewModel.useSharedJobURLIfNeeded(from: appState)
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    viewModel.selectedResumeURL = url
                    viewModel.selectedResumeName = url.lastPathComponent
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
