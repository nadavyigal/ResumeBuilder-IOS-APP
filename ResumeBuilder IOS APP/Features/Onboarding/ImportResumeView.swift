import SwiftUI
import UniformTypeIdentifiers

struct ImportResumeView: View {
    @Environment(AppState.self) private var appState

    @State private var isImporterPresented = false
    @State private var uploadStatus: String?

    var body: some View {
        Section("Master Resume") {
            Button("Import PDF or DOCX") {
                isImporterPresented = true
            }

            if let uploadStatus {
                Text(uploadStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf, .data],
            allowsMultipleSelection: false
        ) { result in
            Task {
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let fileURL = url.standardizedFileURL
                    guard let token = appState.session?.accessToken else {
                        uploadStatus = "Sign in to upload your resume."
                        return
                    }

                    do {
                        let isReadable = await Task.detached(priority: .userInitiated) {
                            let didAccess = fileURL.startAccessingSecurityScopedResource()
                            defer {
                                if didAccess {
                                    fileURL.stopAccessingSecurityScopedResource()
                                }
                            }
                            return FileManager.default.isReadableFile(atPath: fileURL.path)
                        }.value
                        guard isReadable else {
                            uploadStatus = "Selected file can't be read. Try re-selecting it from Files."
                            return
                        }

                        let response = try await appState.apiClient.uploadResume(fileURL: fileURL, token: token)
                        if response.success == true {
                            uploadStatus = "Resume uploaded."
                        } else {
                            uploadStatus = response.error ?? "Upload failed"
                        }
                    } catch {
                        uploadStatus = "Upload failed: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    uploadStatus = error.localizedDescription
                }
            }
        }
    }
}
