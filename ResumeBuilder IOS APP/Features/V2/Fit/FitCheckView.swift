import SwiftUI

/// Step 1 of the Fit-First flow: paste a job description and tap Check Fit.
/// Hidden behind `BackendConfig.isFitCheckEnabled`.
struct FitCheckView: View {
    @Bindable var viewModel: FitCheckViewModel

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            if viewModel.isLoading {
                ResumeOptimizationLoadingView(mode: .fitCheck)
                    .transition(.opacity)
            } else if viewModel.isInVerdictState, let result = viewModel.result {
                FitVerdictView(result: result, viewModel: viewModel)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                entryContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isInVerdictState)
        .navigationTitle(NSLocalizedString("Check Fit", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Entry view

    private var entryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                heroHeader

                jobDescriptionInput

                if viewModel.jobDescriptionTooShort {
                    shortJDWarning
                }

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                checkFitButton

                explainerNote
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(NSLocalizedString("Is this job a fit?", comment: ""))
                .font(.appTitle)
                .foregroundStyle(AppColors.textPrimary)

            Text(NSLocalizedString(
                "Paste the job description below. We'll estimate your fit before you spend time optimizing.",
                comment: ""
            ))
            .font(.appBody)
            .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var jobDescriptionInput: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(NSLocalizedString("Job Description", comment: ""))
                .font(.appHeadline)
                .foregroundStyle(AppColors.textPrimary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                viewModel.jobDescriptionTooShort ? Color.red.opacity(0.7) : AppColors.glassStroke,
                                lineWidth: 1
                            )
                    )

                if viewModel.jobDescription.isEmpty {
                    Text(NSLocalizedString("Paste the job description here…", comment: ""))
                        .font(.appBody)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(AppSpacing.md)
                }

                TextEditor(text: $viewModel.jobDescription)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .padding(AppSpacing.xs)
                    .frame(minHeight: 200)
            }
        }
    }

    private var shortJDWarning: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.orange)
                .imageScale(.small)
            Text(NSLocalizedString(
                "Paste the complete job description for an accurate result.",
                comment: ""
            ))
            .font(.appCaption)
            .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.red)
                .imageScale(.small)
            Text(message)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var checkFitButton: some View {
        GradientButton(title: "Check Fit", isLoading: viewModel.isLoading) {
            Task { await viewModel.checkFit() }
        }
    }

    private var explainerNote: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(AppColors.textTertiary)
                .imageScale(.small)
            Text(NSLocalizedString(
                "Estimated fit vs this job. Not affiliated with any ATS vendor. No optimization credit used.",
                comment: ""
            ))
            .font(.appCaption)
            .foregroundStyle(AppColors.textTertiary)
        }
    }
}

#Preview {
    NavigationStack {
        FitCheckView(
            viewModel: FitCheckViewModel(
                fitCheckService: MockFitCheckService()
            )
        )
    }
    .preferredColorScheme(.dark)
}
