import SwiftUI
import UniformTypeIdentifiers

struct ScanResumeView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: ScanViewModel
    var onAnalyze: ((String, String) -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                GreetingHeader(name: "there", screenTitle: "Scan Resume")
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xl)

                // Upload card
                uploadCard

                // Job description input
                jdInputCard

                // Detected file row
                if let filename = viewModel.detectedFilename {
                    ResumeFileCard(
                        filename: filename,
                        metadata: "Ready to analyze"
                    )
                    .padding(.horizontal, AppSpacing.lg)
                }

                // Analyze CTA
                GradientButton(
                    title: "Analyze Resume",
                    icon: "wand.and.stars",
                    isLoading: viewModel.isUploading
                ) {
                    if let id = viewModel.uploadedResumeId {
                        onAnalyze?(id, viewModel.jobDescription)
                    }
                }
                .disabled(!viewModel.canAnalyze)
                .padding(.horizontal, AppSpacing.lg)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, AppSpacing.lg)
                }

                // Privacy note
                Label("Your resume is encrypted and never shared.", systemImage: "lock.shield.fill")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .screenBackground(showRadialGlow: false)
        .fileImporter(
            isPresented: $viewModel.isImporterPresented,
            allowedContentTypes: [.pdf, .data],
            allowsMultipleSelection: false
        ) { result in
            Task {
                if case .success(let urls) = result, let url = urls.first {
                    await viewModel.handlePickedFile(url: url, token: appState.session?.accessToken)
                }
            }
        }
    }

    // MARK: - Subviews

    private var uploadCard: some View {
        Button {
            viewModel.isImporterPresented = true
        } label: {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous)
                        .fill(AppColors.accentSky.opacity(0.18))
                        .frame(width: 52, height: 52)

                    if viewModel.isUploading {
                        ProgressView().tint(AppColors.accentSky)
                    } else {
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColors.accentSky)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.detectedFilename != nil ? "Change Resume" : "Import Resume")
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("PDF or DOCX")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(AppSpacing.lg)
            .glassCard(cornerRadius: AppRadii.lg)
            .padding(.horizontal, AppSpacing.lg)
        }
        .buttonStyle(GradientButtonStyle())
    }

    private var jdInputCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Job Description")
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textPrimary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                            .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                    )

                if viewModel.jobDescription.isEmpty {
                    Text("Paste the job description here…")
                        .font(.appBody)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(AppSpacing.lg)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.jobDescription)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(AppSpacing.md)
                    .frame(minHeight: 160)
                    .onChange(of: viewModel.jobDescription) { _, new in
                        if new.count > 5000 {
                            viewModel.jobDescription = String(new.prefix(5000))
                        }
                    }
            }

            Text("\(viewModel.jobDescription.count) / 5000")
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.lg)
    }
}

#Preview {
    ScanResumeView(viewModel: ScanViewModel(uploadService: MockResumeUploadService()))
        .environment(AppState())
}
