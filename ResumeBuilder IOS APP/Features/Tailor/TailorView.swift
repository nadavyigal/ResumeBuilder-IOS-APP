import SwiftUI
import UniformTypeIdentifiers

struct TailorView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: TailorViewModel
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tailor")
                        .font(.largeTitle.bold())

                    Text("Upload your resume and paste a LinkedIn/job link. The backend extracts the job description like the web app.")
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
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topLeading) {
                            if viewModel.jobDescription.isEmpty {
                                Text("Optional: paste job description instead")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 16)
                            }
                        }

                    Button {
                        Task { await viewModel.optimize(appState: appState) }
                    } label: {
                        if viewModel.isOptimizing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(appState.isAuthenticated ? "Optimize" : "Sign in to Optimize")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if viewModel.isOptimizing {
                        OptimizingView()
                    }

                    if let reviewId = viewModel.reviewId {
                        DiffReviewView(reviewId: reviewId)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Tailor")
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
