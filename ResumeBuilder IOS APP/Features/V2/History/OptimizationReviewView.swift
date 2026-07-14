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
    /// True after the apply endpoint returns 500 due to a missing DB column — disables Apply until the server is migrated.
    var serverRequiresMigration = false

    private let api: APIClient
    private let applyTimeout: TimeInterval = 120

    init(reviewId: String, api: APIClient = RuntimeServices.sharedAPIClient) {
        self.reviewId = reviewId
        self.api = api
    }

    var isAlreadyApplied: Bool {
        guard let applied = envelope?.review.appliedAt else { return false }
        return !applied.isEmpty
    }

    func load(token: String?) async {
        guard let token else {
            errorMessage = NSLocalizedString("Sign in to load this review.", comment: "")
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await load(with: token)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await appState.callWithFreshToken { token in
                try await self.load(with: token)
            }
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
            errorMessage = NSLocalizedString("Sign in to apply changes.", comment: "")
            return
        }
        guard !includedGroupIds.isEmpty else {
            errorMessage = NSLocalizedString("Select at least one change to apply.", comment: "")
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await applyOrRecover(with: token)
        } catch let apiError as APIClientError {
            switch apiError {
            case .serverError(let status, let message) where status >= 500:
                if message.contains("operation_type") {
                    serverRequiresMigration = true
                    errorMessage = NSLocalizedString("The server needs a database update before changes can be applied. Please try again later or contact support.", comment: "")
                } else {
                    errorMessage = String(format: NSLocalizedString("Server error (%lld). Please try again later.", comment: ""), status)
                }
            default:
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func apply(appState: AppState) async {
        guard !includedGroupIds.isEmpty else {
            errorMessage = NSLocalizedString("Select at least one change to apply.", comment: "")
            return
        }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await appState.callWithFreshToken { token in
                try await self.applyOrRecover(with: token)
            }
        } catch let apiError as APIClientError {
            switch apiError {
            case .serverError(let status, let message) where status >= 500:
                if message.contains("operation_type") {
                    serverRequiresMigration = true
                    errorMessage = NSLocalizedString("The server needs a database update before changes can be applied. Please try again later or contact support.", comment: "")
                } else {
                    errorMessage = String(format: NSLocalizedString("Server error (%lld). Please try again later.", comment: ""), status)
                }
            default:
                errorMessage = apiError.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func load(with token: String) async throws {
        let data: OptimizationReviewEnvelope = try await api.get(
            endpoint: .optimizationReview(id: reviewId),
            token: token
        )
        envelope = data
        includedGroupIds = Set(data.review.groupedChanges.map(\.id))
    }

    private func apply(with token: String) async throws {
        let body: [String: Any] = ["approvedGroupIds": Array(includedGroupIds)]
        let result: OptimizationReviewApplyResponseDTO = try await api.postJSON(
            endpoint: .optimizationReviewApply(id: reviewId),
            body: body,
            token: token,
            timeout: applyTimeout
        )
        if let err = result.error, result.optimizationId == nil {
            errorMessage = err
            return
        }
        applySuccessOptimizationId = result.optimizationId
        if let optimizationId = result.optimizationId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !optimizationId.isEmpty {
            AnalyticsService.shared.track(.optimizationCompleted(optimizationId: optimizationId, reviewId: reviewId))
        }
    }

    private func applyOrRecover(with token: String) async throws {
        do {
            try await apply(with: token)
        } catch {
            if await recoverAppliedState(after: error, token: token) {
                return
            }
            throw error
        }
    }

    private func recoverAppliedState(after error: Error, token: String) async -> Bool {
        guard Self.isTimeout(error) || Self.isAlreadyApplied(error) else { return false }
        guard let data: OptimizationReviewEnvelope = try? await api.get(
            endpoint: .optimizationReview(id: reviewId),
            token: token
        ) else {
            return false
        }

        envelope = data
        includedGroupIds = Set(data.review.groupedChanges.map(\.id))

        if let optimizationId = data.review.optimizationId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !optimizationId.isEmpty {
            applySuccessOptimizationId = optimizationId
            errorMessage = nil
            AnalyticsService.shared.track(.optimizationCompleted(optimizationId: optimizationId, reviewId: reviewId))
            return true
        }

        if isAlreadyApplied {
            errorMessage = NSLocalizedString("This review was already applied. Open the optimized resume from the Optimized tab.", comment: "")
            return true
        }

        return false
    }

    private static func isTimeout(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }

    private static func isAlreadyApplied(_ error: Error) -> Bool {
        guard case .serverError(_, let message) = error as? APIClientError else { return false }
        return message.lowercased().contains("already") && message.lowercased().contains("applied")
    }
}

struct OptimizationReviewView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: OptimizationReviewViewModel
    var onAppliedOptimization: ((String) -> Void)? = nil

    @State private var navigateToDetail = false
    @State private var handledAppliedOptimizationId: String?

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
                    if viewModel.serverRequiresMigration {
                        migrationBanner
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
                            await viewModel.apply(appState: appState)
                        }
                    }
                    .disabled(viewModel.serverRequiresMigration || viewModel.isSubmitting)
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
            handleAppliedOptimization(newId)
        }
        .task {
            await viewModel.load(appState: appState)
        }
    }

    private func handleAppliedOptimization(_ candidate: String?) {
        guard let optimizationId = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !optimizationId.isEmpty,
              handledAppliedOptimizationId != optimizationId else {
            return
        }

        handledAppliedOptimizationId = optimizationId
        appState.latestOptimizationId = optimizationId
        if let onAppliedOptimization {
            onAppliedOptimization(optimizationId)
        } else {
            navigateToDetail = true
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

    private var migrationBanner: some View {
        Label("Apply is temporarily unavailable — a server update is required. Changes will be available again once the update is complete.", systemImage: "exclamationmark.triangle.fill")
            .font(.appCaption)
            .foregroundStyle(.orange)
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadii.md))
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
