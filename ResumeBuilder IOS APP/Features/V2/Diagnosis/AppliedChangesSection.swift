import SwiftUI

/// The before/after detail that used to live on the Optimization Review screen.
///
/// The review screen left the happy path (founder decision, 2026-08-12): the fit
/// check is now the approval, every change is applied, and the user lands on the
/// finished résumé. That removes the only place the user could see what actually
/// changed — so it moves here, onto Resume Diagnosis, reachable from the résumé.
///
/// Because every change is applied rather than ticked, this section is the
/// accountability surface: changes the safety policy would have held back are
/// still applied, and are marked so the user can find and fix them.
@Observable
@MainActor
final class AppliedChangesViewModel {
    private(set) var envelope: OptimizationReviewEnvelope?
    private(set) var flaggedGroupIds: Set<String> = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let api: APIClient

    init(api: APIClient = RuntimeServices.sharedAPIClient) {
        self.api = api
    }

    var groups: [ReviewChangeGroupDTO] { envelope?.review.groupedChanges ?? [] }

    /// The score before the rewrite, as a percentage.
    var originalScore: Int? { Self.percent(envelope?.review.atsPreview?.before) }

    /// The score after the rewrite that is now applied, as a percentage.
    var currentScore: Int? { Self.percent(envelope?.review.atsPreview?.after) }

    func load(reviewId: String?, appState: AppState) async {
        #if DEBUG
        print("📄 [CHANGES] load reviewId=\(reviewId ?? "nil") hasEnvelope=\(envelope != nil) isLoading=\(isLoading)")
        #endif
        guard let reviewId, envelope == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let data: OptimizationReviewEnvelope = try await appState.callWithFreshToken { token in
                try await api.get(endpoint: .optimizationReview(id: reviewId), token: token)
            }
            envelope = data
            flaggedGroupIds = OptimizationAutoApplyService.flaggedGroupIds(in: data)
            #if DEBUG
            print("📄 [CHANGES] loaded \(data.review.groupedChanges.count) grouped changes")
            #endif
        } catch {
            errorMessage = error.localizedDescription
            #if DEBUG
            print("📄 [CHANGES] load FAILED: \(error.localizedDescription)")
            #endif
        }
    }

    /// The backend has sent both 0-1 fractions and 0-100 percentages on this
    /// field, so normalise rather than trusting either.
    private static func percent(_ value: Double?) -> Int? {
        guard let value else { return nil }
        return Int((value <= 1 ? value * 100 : value).rounded())
    }
}

struct AppliedChangesSection: View {
    @Environment(AppState.self) private var appState
    let reviewId: String?
    @State private var viewModel = AppliedChangesViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.envelope == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else if !viewModel.groups.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    header
                    scoreRow
                    ForEach(viewModel.groups) { group in
                        changeCard(group)
                    }
                }
            }
        }
        .task(id: reviewId) {
            await viewModel.load(reviewId: reviewId, appState: appState)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("What changed")
                .font(.appHeadline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
            Text("Your résumé before and after, line by line")
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
        }
    }

    /// Both numbers, always together.
    ///
    /// A single "match score" is ambiguous once a rewrite has been applied — the
    /// user cannot tell whether it is what they started with or what they now
    /// have. Showing the pair removes the question.
    @ViewBuilder
    private var scoreRow: some View {
        if let original = viewModel.originalScore, let current = viewModel.currentScore {
            HStack(spacing: AppSpacing.lg) {
                scorePill(title: "Original score", value: original, isCurrent: false)
                Image(systemName: "arrow.forward")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
                scorePill(title: "Match score", value: current, isCurrent: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
            .glassCard(cornerRadius: AppRadii.md)
        }
    }

    private func scorePill(title: String, value: Int, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
            Text("\(value)%")
                .font(.appHeadline.weight(.bold))
                .foregroundStyle(isCurrent ? AppColors.accentTeal : AppColors.textSecondary)
        }
    }

    private func changeCard(_ group: ReviewChangeGroupDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.section)
                        .font(.appCaption.weight(.bold))
                        .foregroundStyle(AppColors.textTertiary)
                    Text(group.title)
                        .font(.appSubheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer(minLength: AppSpacing.xs)
                if viewModel.flaggedGroupIds.contains(group.id) {
                    checkThisLabel
                }
            }

            if !group.summary.isEmpty {
                Text(group.summary)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            excerpt(label: "Before", text: group.beforeExcerpt, isAfter: false)
            excerpt(label: "After", text: group.afterExcerpt, isAfter: true)
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    /// Marks a change that was applied but that the safety policy would not have
    /// pre-selected — an unresolved placeholder, a title or date rewrite, a
    /// numerical claim. Applied because the flow no longer asks, surfaced because
    /// the user should not have to discover it in a PDF.
    private var checkThisLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Check this")
                .font(.appCaption.weight(.bold))
        }
        .foregroundStyle(AppColors.accentViolet)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 4)
        .background(AppColors.accentViolet.opacity(0.14), in: Capsule())
    }

    @ViewBuilder
    private func excerpt(label: String, text: String, isAfter: Bool) -> some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(label))
                    .font(.appCaption.weight(.bold))
                    .foregroundStyle(isAfter ? AppColors.accentTeal : AppColors.textTertiary)
                Text(text)
                    .font(.appCaption)
                    .foregroundStyle(isAfter ? AppColors.textPrimary : AppColors.textSecondary)
                    .strikethrough(!isAfter, color: AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.sm)
            .background(
                (isAfter ? AppColors.accentTeal.opacity(0.08) : Color.white.opacity(0.04)),
                in: RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous)
            )
        }
    }
}
