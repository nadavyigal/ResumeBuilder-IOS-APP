import SwiftUI

/// Sheet presented from the Tailor tab to let the user pick a previously saved resume.
/// Selecting a row downloads the PDF into the sandbox cache and calls `onSelect`.
struct SavedResumePickerSheet: View {
    @Environment(AppState.self) private var appState
    @Bindable var libraryViewModel: ResumeLibraryViewModel
    var onSelect: (URL, String) -> Void

    @State private var isDownloading: String? = nil
    @State private var downloadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if libraryViewModel.isLoading {
                    ProgressView("Loading saved resumes…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if libraryViewModel.resumes.isEmpty {
                    ContentUnavailableView(
                        "No saved resumes",
                        systemImage: "books.vertical",
                        description: Text("Resumes you save after uploading will appear here.")
                    )
                } else {
                    List {
                        ForEach(libraryViewModel.resumes) { resume in
                            resumeRow(resume)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        if let token = appState.session?.accessToken {
                                            Task { await libraryViewModel.delete(id: resume.id, token: token) }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved Resumes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSelect(URL(fileURLWithPath: "/dev/null"), "")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func resumeRow(_ resume: SavedResume) -> some View {
        let displayName = resume.displayName ?? resume.filename
        let isThisDownloading = isDownloading == resume.id

        Button {
            guard !isThisDownloading else { return }
            Task {
                guard let token = appState.session?.accessToken else { return }
                isDownloading = resume.id
                downloadError = nil
                do {
                    let localURL = try await libraryViewModel.downloadToCache(resume: resume, token: token)
                    isDownloading = nil
                    onSelect(localURL, displayName)
                } catch {
                    isDownloading = nil
                    downloadError = "Download failed: \(error.localizedDescription)"
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "doc.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let size = resume.sizeBytes {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isThisDownloading {
                    ProgressView()
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SavedResumePickerSheet(
        libraryViewModel: ResumeLibraryViewModel(service: MockResumeLibraryService()),
        onSelect: { _, _ in }
    )
    .environment(AppState())
}
