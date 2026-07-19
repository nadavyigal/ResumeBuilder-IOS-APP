import SwiftUI

/// Sheet presented from the Tailor tab to let the user pick a previously saved resume.
/// Selecting a row downloads the PDF into the sandbox cache and calls `onSelect`.
struct SavedResumePickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var libraryViewModel: ResumeLibraryViewModel
    var onSelect: (URL, String) -> Void

    @State private var isDownloading: String? = nil
    @State private var downloadError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let downloadError {
                    errorBanner(downloadError)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                pickerContent
            }
            .navigationTitle("Saved Resumes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var pickerContent: some View {
        if libraryViewModel.isLoading {
            ProgressView("Loading saved resumes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if libraryViewModel.resumes.isEmpty {
            ContentUnavailableView(
                "No saved resumes",
                systemImage: "books.vertical",
                description: Text("Optimized resumes you save from Preview will appear here.")
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

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func resumeRow(_ resume: SavedResume) -> some View {
        let displayName = resume.displayName ?? resume.filename
        let isThisDownloading = isDownloading == resume.id

        Button {
            guard !isThisDownloading else { return }
            Task {
                isDownloading = resume.id
                downloadError = nil
                do {
                    let localURL = try await appState.callWithFreshToken { token in
                        try await libraryViewModel.downloadToCache(resume: resume, token: token)
                    }
                    isDownloading = nil
                    onSelect(localURL, displayName)
                } catch {
                    isDownloading = nil
                    downloadError = NSLocalizedString("Download failed", comment: "")
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
                    Text(resumeMetadata(resume))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private func resumeMetadata(_ resume: SavedResume) -> String {
        var values = [String(resume.createdAt.prefix(10))]
        if let size = resume.sizeBytes {
            values.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
        }
        return values.joined(separator: " · ")
    }
}

#Preview {
    SavedResumePickerSheet(
        libraryViewModel: ResumeLibraryViewModel(service: MockResumeLibraryService()),
        onSelect: { _, _ in }
    )
    .environment(AppState())
}
