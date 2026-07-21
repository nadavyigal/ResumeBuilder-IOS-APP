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
    private var viewedGroupIds: Set<String> = []
    private var blockedGroupIds: Set<String> = []
    /// Story 9: evidence resolved once per load — quotes are verbatim substrings
    /// of the delivered résumé/job text, never fabricated (see contract doc).
    private var evidenceByGroupId: [String: RecommendationEvidence] = [:]

    init(reviewId: String, api: APIClient = RuntimeServices.sharedAPIClient) {
        self.reviewId = reviewId
        self.api = api
    }

    var isAlreadyApplied: Bool {
        guard let applied = envelope?.review.appliedAt else { return false }
        return !applied.isEmpty
    }

    var scoreAssessment: RecommendationSafetyPolicy.ScoreAssessment {
        RecommendationSafetyPolicy.assessScore(
            before: envelope?.review.atsPreview?.before,
            after: envelope?.review.atsPreview?.after
        )
    }

    var selectableGroupCount: Int {
        envelope?.review.groupedChanges.filter { assessment(for: $0).canSelect }.count ?? 0
    }

    func assessment(for group: ReviewChangeGroupDTO) -> RecommendationSafetyPolicy.Assessment {
        RecommendationSafetyPolicy.assess(
            before: group.beforeExcerpt,
            after: group.afterExcerpt,
            context: [group.section, group.title, group.summary].joined(separator: "\n")
        )
    }

    func evidence(for group: ReviewChangeGroupDTO) -> RecommendationEvidence {
        evidenceByGroupId[group.id] ?? .empty
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
        guard let group = envelope?.review.groupedChanges.first(where: { $0.id == groupId }) else { return }
        let safety = assessment(for: group)
        guard safety.canSelect else { return }
        let evidenceState = evidence(for: group).isEmpty ? "without_evidence" : "with_evidence"
        if includedGroupIds.contains(groupId) {
            includedGroupIds.remove(groupId)
            AnalyticsService.shared.track(
                .recommendationSkipped(
                    surface: "optimization_review",
                    safetyState: safety.analyticsState,
                    evidenceState: evidenceState,
                    reviewId: reviewId,
                    itemId: group.id
                )
            )
        } else {
            includedGroupIds.insert(groupId)
            AnalyticsService.shared.track(
                .recommendationIncluded(
                    surface: "optimization_review",
                    safetyState: safety.analyticsState,
                    evidenceState: evidenceState,
                    reviewId: reviewId,
                    itemId: group.id
                )
            )
        }
    }

    func markViewed(groupId: String) {
        guard viewedGroupIds.insert(groupId).inserted,
              let group = envelope?.review.groupedChanges.first(where: { $0.id == groupId }) else { return }
        let safety = assessment(for: group)
        AnalyticsService.shared.track(
            .recommendationViewed(
                surface: "optimization_review",
                safetyState: safety.analyticsState,
                reviewId: reviewId,
                itemId: group.id
            )
        )
        let groupEvidence = evidence(for: group)
        if !groupEvidence.isEmpty, !safety.isSuppressed {
            AnalyticsService.shared.track(
                .recommendationEvidenceShown(
                    surface: "optimization_review",
                    jobQuoteCount: groupEvidence.jobQuotes.count,
                    resumeQuoteCount: groupEvidence.resumeQuotes.count,
                    reviewId: reviewId,
                    itemId: group.id
                )
            )
        }
        if safety.isSuppressed, blockedGroupIds.insert(groupId).inserted {
            AnalyticsService.shared.track(
                .recommendationBlocked(
                    surface: "optimization_review",
                    reason: safety.analyticsReason,
                    reviewId: reviewId,
                    itemId: group.id
                )
            )
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
        AnalyticsService.shared.track(
            .optimizationApplyStarted(reviewId: reviewId, approvedGroupCount: includedGroupIds.count)
        )
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await applyOrRecover(with: token)
        } catch let apiError as APIClientError {
            trackApplyFailure(apiError)
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
            trackApplyFailure(error)
            errorMessage = error.localizedDescription
        }
    }

    func apply(appState: AppState) async {
        guard !includedGroupIds.isEmpty else {
            errorMessage = NSLocalizedString("Select at least one change to apply.", comment: "")
            return
        }
        AnalyticsService.shared.track(
            .optimizationApplyStarted(reviewId: reviewId, approvedGroupCount: includedGroupIds.count)
        )
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await appState.callWithFreshToken { token in
                try await self.applyOrRecover(with: token)
            }
        } catch let apiError as APIClientError {
            trackApplyFailure(apiError)
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
            trackApplyFailure(error)
            errorMessage = error.localizedDescription
        }
    }

    private func load(with token: String) async throws {
        let data: OptimizationReviewEnvelope = try await api.get(
            endpoint: .optimizationReview(id: reviewId),
            token: token
        )
        envelope = data
        initializeSelections(for: data)
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
            AnalyticsService.shared.track(
                .optimizationApplyFailed(reviewId: reviewId, errorCode: "backend_error")
            )
            return
        }
        applySuccessOptimizationId = result.optimizationId
        if let optimizationId = result.optimizationId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !optimizationId.isEmpty {
            AnalyticsService.shared.track(
                .optimizationApplySucceeded(optimizationId: optimizationId, reviewId: reviewId)
            )
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
        initializeSelections(for: data)

        if let optimizationId = data.review.optimizationId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !optimizationId.isEmpty {
            applySuccessOptimizationId = optimizationId
            errorMessage = nil
            AnalyticsService.shared.track(.optimizationStateRecovered(optimizationId: optimizationId))
            AnalyticsService.shared.track(
                .optimizationApplySucceeded(optimizationId: optimizationId, reviewId: reviewId)
            )
            AnalyticsService.shared.track(.optimizationCompleted(optimizationId: optimizationId, reviewId: reviewId))
            return true
        }

        if isAlreadyApplied {
            errorMessage = NSLocalizedString("This review was already applied. Open the optimized resume from the Optimized tab.", comment: "")
            return true
        }

        return false
    }

    private func trackApplyFailure(_ error: Error) {
        AnalyticsService.shared.track(
            .optimizationApplyFailed(reviewId: reviewId, errorCode: ExportFailureCode.code(for: error))
        )
    }

    private static func isTimeout(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }

    private func initializeSelections(for data: OptimizationReviewEnvelope) {
        let nonPositive = RecommendationSafetyPolicy.assessScore(
            before: data.review.atsPreview?.before,
            after: data.review.atsPreview?.after
        ).isNonPositive
        includedGroupIds = Set(data.review.groupedChanges.compactMap { group in
            assessment(for: group).defaultIncluded(reviewHasNonPositiveDelta: nonPositive) ? group.id : nil
        })
        viewedGroupIds.removeAll()
        blockedGroupIds.removeAll()
        resolveEvidence(for: data)
    }

    /// Evidence never affects selection defaults or the safety policy — it only
    /// informs the user (contract §5: evidence never auto-approves).
    private func resolveEvidence(for data: OptimizationReviewEnvelope) {
        let jobText = data.jobDescription.flatMap { $0.cleanText ?? $0.rawText }
        let resumeText = data.resume?.rawText
        evidenceByGroupId = Dictionary(
            data.review.groupedChanges.map { group in
                (
                    group.id,
                    RecommendationEvidence.resolve(
                        backend: group.evidence,
                        afterExcerpt: group.afterExcerpt,
                        jobText: jobText,
                        resumeText: resumeText
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func isAlreadyApplied(_ error: Error) -> Bool {
        guard case .serverError(_, let message) = error as? APIClientError else { return false }
        return message.lowercased().contains("already") && message.lowercased().contains("applied")
    }
}

/// Keeps a review fetch alive when SwiftUI refreshes the presenting screen.
/// Navigation destinations are value views, so constructing a model inline there
/// can replace the instance that just received the review response.
@Observable
@MainActor
final class OptimizationReviewDestinationState {
    private(set) var reviewId: String
    private(set) var viewModel: OptimizationReviewViewModel

    init(reviewId: String) {
        self.reviewId = reviewId
        self.viewModel = OptimizationReviewViewModel(reviewId: reviewId)
    }

    func activate(reviewId: String) {
        guard self.reviewId != reviewId else { return }
        self.reviewId = reviewId
        viewModel = OptimizationReviewViewModel(reviewId: reviewId)
    }
}

/// Stable owner for an optimization-review model used from navigation destinations.
struct OptimizationReviewDestination: View {
    let reviewId: String
    let onAppliedOptimization: ((String) -> Void)?
    @State private var state: OptimizationReviewDestinationState

    init(
        reviewId: String,
        onAppliedOptimization: ((String) -> Void)? = nil
    ) {
        self.reviewId = reviewId
        self.onAppliedOptimization = onAppliedOptimization
        _state = State(initialValue: OptimizationReviewDestinationState(reviewId: reviewId))
    }

    var body: some View {
        OptimizationReviewView(
            viewModel: state.viewModel,
            onAppliedOptimization: onAppliedOptimization
        )
        .onChange(of: reviewId) { _, newReviewId in
            state.activate(reviewId: newReviewId)
        }
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
                    if viewModel.scoreAssessment.isNonPositive {
                        nonImprovingScoreBanner
                    }
                    ForEach(env.review.groupedChanges) { group in
                        ReviewChangeCard(
                            group: group,
                            safety: viewModel.assessment(for: group),
                            evidence: viewModel.evidence(for: group),
                            isIncluded: viewModel.includedGroupIds.contains(group.id),
                            isLocked: viewModel.isAlreadyApplied,
                            onToggle: { viewModel.toggleInclude(groupId: group.id) },
                            onViewed: { viewModel.markViewed(groupId: group.id) }
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
            if viewModel.envelope != nil, !viewModel.isAlreadyApplied,
               viewModel.applySuccessOptimizationId == nil {
                VStack(spacing: AppSpacing.sm) {
                    Text(
                        "\(viewModel.includedGroupIds.count) of \(viewModel.selectableGroupCount) available changes selected"
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
                    .disabled(
                        viewModel.serverRequiresMigration
                        || viewModel.isSubmitting
                        || viewModel.includedGroupIds.isEmpty
                    )
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
                    Image(systemName: "arrow.forward")
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

    private var nonImprovingScoreBanner: some View {
        Label(
            "The projected score does not improve. No changes are selected by default—review each suggestion and include only changes you trust.",
            systemImage: "exclamationmark.shield.fill"
        )
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
    let safety: RecommendationSafetyPolicy.Assessment
    let evidence: RecommendationEvidence
    let isIncluded: Bool
    let isLocked: Bool
    let onToggle: () -> Void
    let onViewed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(safety.isSuppressed ? "SAFETY CHECK" : group.section.uppercased())
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                Spacer()
                if !isLocked {
                    Button(buttonTitle) {
                        onToggle()
                    }
                    .font(.appCaption)
                    .foregroundStyle(AppColors.gradientMid)
                    .disabled(!safety.canSelect)
                }
            }

            if safety.isSuppressed {
                Text("Suggestion hidden for safety")
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)
            } else {
                Text(group.title)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(group.summary)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let warning = safety.primaryReason?.userMessage {
                Label(warning, systemImage: "exclamationmark.shield.fill")
                    .font(.appCaption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Before")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                Text(group.beforeExcerpt)
                    .font(.appBody)
                    .foregroundStyle(.red.opacity(0.9))
                    .strikethrough(true, color: .red.opacity(0.45))

                if !safety.isSuppressed {
                    Text("After")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.top, AppSpacing.xs)
                    Text(group.afterExcerpt)
                        .font(.appBody)
                        .foregroundStyle(AppColors.accentTeal)
                }
            }

            if !safety.isSuppressed, !evidence.isEmpty {
                evidenceSection
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .opacity(isIncluded || safety.isSuppressed ? 1 : 0.68)
        .onAppear(perform: onViewed)
    }

    /// Read-only by design: quotes are verbatim excerpts of the user's own
    /// résumé and target job. Nothing here is editable or submittable — the
    /// apply contract only ever receives group IDs.
    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Why this change")
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
                .padding(.top, AppSpacing.xs)

            ForEach(evidence.jobQuotes, id: \.self) { quote in
                evidenceQuote(quote, label: NSLocalizedString("From the job post", comment: "Evidence quote source"))
            }
            ForEach(evidence.resumeQuotes, id: \.self) { quote in
                evidenceQuote(quote, label: NSLocalizedString("From your resume", comment: "Evidence quote source"))
            }
        }
    }

    private func evidenceQuote(_ quote: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
            Text("\u{201C}\(quote)\u{201D}")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accentTeal.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadii.md))
        .accessibilityElement(children: .combine)
    }

    private var buttonTitle: String {
        if !safety.canSelect { return NSLocalizedString("Blocked", comment: "Unsafe recommendation") }
        if isIncluded { return NSLocalizedString("Skip", comment: "Exclude recommendation") }
        if safety.requiresExplicitConfirmation {
            return NSLocalizedString("Confirm & include", comment: "Explicitly include factual recommendation")
        }
        return NSLocalizedString("Accept", comment: "Accept recommendation")
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
