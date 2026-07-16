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
            } else {
                switch viewModel.continuationStep {
                case .showVerdict:
                    if let result = viewModel.result {
                        FitVerdictView(result: result, viewModel: viewModel)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                case .showFailure:
                    failureContent
                        .transition(.opacity)
                // A job carried from Home needs no confirmation form — the
                // automatic check is kicked off by .task below.
                case .runAutomatically:
                    ResumeOptimizationLoadingView(mode: .fitCheck)
                        .transition(.opacity)
                case .askForJob, .editTarget:
                    entryContent
                        .transition(.opacity)
                }
            }
        }
        .task { await viewModel.beginCarriedFitCheck() }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.continuationStep)
        .navigationTitle(NSLocalizedString("Check Fit", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A failed fit explains itself and offers the target back to the user —
    /// it never silently reverts to the confirmation form Story 8 removes.
    private var failureContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                heroHeader

                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                Text("Your résumé and diagnosis are untouched. You can adjust the target job and try again, or skip fit and optimize anyway.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                GradientButton(title: "Edit target job", isLoading: false) {
                    viewModel.editTarget()
                }

                Button {
                    viewModel.skip()
                } label: {
                    Text("Skip fit and optimize")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)

                explainerNote
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Entry view

    private var entryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                heroHeader

                if !viewModel.jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    jobLinkSummary
                }

                jobDescriptionInput

                jobInputGuidance

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
                viewModel.jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Paste the job description below. We'll estimate your fit before you spend time optimizing."
                    : "We'll use the job link you added to estimate your fit before you spend time optimizing.",
                comment: ""
            ))
            .font(.appBody)
            .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var jobLinkSummary: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "link.circle.fill")
                .foregroundStyle(AppColors.accentSky)
                .imageScale(.medium)

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Using Job Link", comment: ""))
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(viewModel.jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accentSky.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.accentSky.opacity(0.25), lineWidth: 1)
        )
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
                    Text(NSLocalizedString(
                        viewModel.jobDescriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Paste the job description here…"
                            : "Optional: paste the job description for more detail…",
                        comment: ""
                    ))
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

    private var jobInputGuidance: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: viewModel.canCheck ? "checkmark.circle.fill" : "info.circle.fill")
                .foregroundStyle(viewModel.canCheck ? Color.green : Color.orange)
                .imageScale(.small)
            Text(viewModel.jobInputEvaluation.inlineGuidance)
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
            Task {
                // While editing, this re-checks the new target and leaves edit mode.
                if viewModel.isEditingTarget {
                    await viewModel.applyEditedTarget()
                } else {
                    await viewModel.checkFit()
                }
            }
        }
        .disabled(!viewModel.canCheck || viewModel.isLoading)
        .opacity(viewModel.canCheck ? 1 : 0.55)
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
