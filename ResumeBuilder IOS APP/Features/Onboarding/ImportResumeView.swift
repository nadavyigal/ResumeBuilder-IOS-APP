import SwiftUI
import UniformTypeIdentifiers

/// **Not in the upload funnel, because it is not reachable.** Verified 2026-08-04:
/// `ImportResumeView` is constructed nowhere in the app — no view, route, or
/// settings screen presents it. Its six silent exit paths (no url, no token,
/// unreadable, server rejected, threw, picker failed) therefore cannot be
/// costing any live user anything, and it is left uninstrumented on purpose
/// (WP-66 S1). The same applies to the "Sign in to upload your resume" hard stop
/// below: no guest can reach it today.
///
/// If this view is ever presented, it must gain the paired CTA-seen /
/// file-selected events with a matching `source`, one event per exit path, and
/// the shared pdf/docx/doc content-type list before it ships.
struct ImportResumeView: View {
    @Environment(AppState.self) private var appState

    @State private var isImporterPresented = false
    @State private var uploadStatus: String?

    var body: some View {
        Section("Master Resume") {
            Button("Import PDF") {
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
            allowedContentTypes: [.pdf],
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
                            uploadStatus = response.error ?? NSLocalizedString("Upload failed", comment: "")
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
