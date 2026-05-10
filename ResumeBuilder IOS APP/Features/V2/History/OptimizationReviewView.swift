import SwiftUI

@Observable
@MainActor
final class OptimizationReviewViewModel {
    let reviewId: String

    var envelope: OptimizationReviewEnvelope?
    /// Group IDs to include in apply (web parity: skipped groups excluded).
    var includedGroupIds: Set<String> = []
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String?
    var applySuccessOptimizationId: String?

    private let api = APIClient()

    init(reviewId: String) {
        self.reviewId = reviewId
    }

    var isAlreadyApplied: Bool {
        guard let applied = envelope?.review.appliedAt else { return false }
        return !applied.isEmpty
    }

    func load(token: String?) async {
        guard let token else {
            errorMessage = "Sign in to load this review."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let data: OptimizationReviewEnvelope = try await api.get(
                endpoint: .optimizationReview(id: reviewId),
                token: token
            )
            envelope = data
            includedGroupIds = Set(data.review.groupedChanges.map(\.id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleInclude(groupId: String) {
        if includedGroupIds.contains(groupId) {
            includedGroupIds.remove(groupId)
        } else {
            includedGroupIds.insert(groupId)
        }
    }

    func apply(token: String?) async {
        guard let token else {
            errorMessage = "Sign in to apply changes."
            return
        }
        guard !includedGroupIds.isEmpty else {
            errorMessage = "Select at least one change to apply."
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let body: [String: Any] = ["approvedGroupIds": Array(includedGroupIds)]
            let result: OptimizationReviewApplyResponseDTO = try await api.postJSON(
                endpoint: .optimizationReviewApply(id: reviewId),
                body: body,
                token: token
            )
            if let err = result.error, result.optimizationId == nil {
                errorMessage = err
                return
            }
            applySuccessOptimizationId = result.optimizationId
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct OptimizationReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: OptimizationReviewViewModel

    @State private var navigateToDetail = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.xl)
                } else if let env = viewModel.envelope {
                    header(env)
                    if viewModel.isAlreadyApplied {
                        appliedBanner
                    }
                    ForEach(env.review.groupedChanges) { group in
                        ReviewChangeCard(
                            group: group,
                            isIncluded: viewModel.includedGroupIds.contains(group.id),
                            isLocked: viewModel.isAlreadyApplied,
                            onToggle: { viewModel.toggleInclude(groupId: group.id) }
                        )
                    }
                }

                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.appCaption)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 120)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
        }
        .scrollIndicators(.hidden)
        .screenBackground(showRadialGlow: false)
        .navigationTitle("Optimization Review")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let env = viewModel.envelope, !viewModel.isAlreadyApplied,
               viewModel.applySuccessOptimizationId == nil {
                VStack(spacing: AppSpacing.sm) {
                    Text(
                        "\(viewModel.includedGroupIds.count) of \(env.review.groupedChanges.count) changes selected"
                    )
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)

                    GradientButton(
                        title: "Apply selected changes",
                        icon: "checkmark.circle.fill",
                        isLoading: viewModel.isSubmitting
                    ) {
                        Task {
                            await viewModel.apply(token: appState.session?.accessToken)
                        }
                    }
                }
                .padding(AppSpacing.lg)
                .background(.ultraThinMaterial.opacity(0.9))
            }
        }
        .navigationDestination(isPresented: $navigateToDetail) {
            if let optId = viewModel.applySuccessOptimizationId {
                OptimizedResumeView(
                    viewModel: OptimizedResumeViewModel(
                        optimizationId: optId,
                        atsScoreBefore: viewModel.envelope.flatMap(\.review.atsPreview).flatMap {
                            $0.before.map { Int(($0 <= 1 ? $0 * 100 : $0).rounded()) }
                        },
                        atsScoreAfter: viewModel.envelope.flatMap(\.review.atsPreview).flatMap {
                            $0.after.map { Int(($0 <= 1 ? $0 * 100 : $0).rounded()) }
                        },
                        jobTitle: viewModel.envelope?.jobDescription?.title,
                        company: viewModel.envelope?.jobDescription?.company
                    )
                )
            }
        }
        .onChange(of: viewModel.applySuccessOptimizationId) { _, newId in
            if newId != nil { navigateToDetail = true }
        }
        .task {
            await viewModel.load(token: appState.session?.accessToken)
        }
    }

    private func header(_ env: OptimizationReviewEnvelope) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let title = env.jobDescription?.title {
                Text(title)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)
            }
            if let company = env.jobDescription?.company {
                Text(company)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            if let preview = env.review.atsPreview {
                HStack(spacing: AppSpacing.md) {
                    if let before = preview.before {
                        Text("Before \(percentLabel(before))")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Image(systemName: "arrow.right")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textTertiary)
                    if let after = preview.after {
                        Text("After \(percentLabel(after))")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.accentTeal)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var appliedBanner: some View {
        Label("This review was already applied on the web or another device.", systemImage: "checkmark.seal.fill")
            .font(.appCaption)
            .foregroundStyle(AppColors.textSecondary)
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.accentTeal.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadii.md))
    }

    private func percentLabel(_ value: Double) -> String {
        let p = value <= 1 ? value * 100 : value
        return "\(Int(p.rounded()))%"
    }
}

private struct ReviewChangeCard: View {
    let group: ReviewChangeGroupDTO
    let isIncluded: Bool
    let isLocked: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(group.section.uppercased())
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                if !isLocked {
                    Button(isIncluded ? "Skip" : "Include") {
                        onToggle()
                    }
                    .font(.appCaption)
                    .foregroundStyle(AppColors.gradientMid)
                }
            }

            Text(group.title)
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textPrimary)

            Text(group.summary)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Before")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                Text(group.beforeExcerpt)
                    .font(.appBody)
                    .foregroundStyle(.red.opacity(0.9))
                    .strikethrough(true, color: .red.opacity(0.45))

                Text("After")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.top, AppSpacing.xs)
                Text(group.afterExcerpt)
                    .font(.appBody)
                    .foregroundStyle(AppColors.accentTeal)
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .opacity(isIncluded ? 1 : 0.55)
    }
}

#Preview {
    NavigationStack {
        OptimizationReviewView(
            viewModel: OptimizationReviewViewModel(reviewId: "preview-review")
        )
    }
    .environment(AppState())
}
