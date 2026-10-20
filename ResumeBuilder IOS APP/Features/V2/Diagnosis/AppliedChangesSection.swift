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

    /// `envelope` is for tests and the DEBUG smoke harness: a section that
    /// starts with its data never fetches.
    init(api: APIClient = RuntimeServices.sharedAPIClient, envelope: OptimizationReviewEnvelope? = nil) {
        self.api = api
        if let envelope {
            self.envelope = envelope
            self.flaggedGroupIds = OptimizationAutoApplyService.flaggedGroupIds(in: envelope)
        }
    }

    var groups: [ReviewChangeGroupDTO] { envelope.map(Self.appliedGroups(in:)) ?? [] }

    /// The section changes, which are always applied. "Add only if true" claims
    /// are left out: the server does not record which ones the user confirmed,
    /// so listing them here could show a claim as applied that was declined.
    static func appliedGroups(in envelope: OptimizationReviewEnvelope) -> [ReviewChangeGroupDTO] {
        envelope.review.groupedChanges.filter { !$0.isConfirmClaim }
    }

    // No score lives here. The review's `ats_preview_json` is a projection
    // made before the apply; the stored result can differ (45 -> 49 projected,
    // 67 stored on 2026-10-19). The headline above owns the number, from the
    // stored detail only.

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
}

/// A human name for a review section.
///
/// The server sends the section as a key ("summary", "experience"), and the
/// screen printed it as is: "summary" in lower case, in English, inside the
/// Hebrew UI. Known keys are localized; an unknown one still reads as words.
enum ReviewSectionName {
    static func label(for section: String) -> String {
        let key = section.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "summary": return NSLocalizedString("Summary", comment: "Résumé section name")
        case "contact": return NSLocalizedString("Contact details", comment: "Résumé section name")
        case "skills": return NSLocalizedString("Skills", comment: "Résumé section name")
        case "experience": return NSLocalizedString("Experience", comment: "Résumé section name")
        case "education": return NSLocalizedString("Education", comment: "Résumé section name")
        case "certifications": return NSLocalizedString("Certifications", comment: "Résumé section name")
        case "projects": return NSLocalizedString("Projects", comment: "Résumé section name")
        default:
            let words = key
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            return words.prefix(1).uppercased() + words.dropFirst()
        }
    }

    /// A change title or summary in the user's language.
    ///
    /// The server writes them from a fixed English set (web
    /// `SECTION_DESCRIPTORS`), and those exact strings are keys in
    /// Localizable.xcstrings. Anything else comes back unchanged.
    static func localizedCopy(_ serverText: String) -> String {
        Bundle.main.localizedString(forKey: serverText, value: serverText, table: nil)
    }
}

struct AppliedChangesSection: View {
    @Environment(AppState.self) private var appState
    let reviewId: String?
    @State private var viewModel: AppliedChangesViewModel

    init(reviewId: String?, preloaded: OptimizationReviewEnvelope? = nil) {
        self.reviewId = reviewId
        _viewModel = State(initialValue: AppliedChangesViewModel(envelope: preloaded))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // The task lives on a view that is ALWAYS in the hierarchy.
            //
            // It used to hang off a `Group` whose every branch was false on the
            // first render — not loading yet, no groups yet — so the Group
            // produced no content, contributed nothing to layout, and never
            // reliably received the task. `load()` therefore never ran, `groups`
            // stayed empty, and the branch stayed false: a view that could not
            // bootstrap itself.
            //
            // That is why no GET of /api/v1/optimization-reviews ever appeared
            // in a device log, in any build, no matter what the review-id
            // mapping did. Three fixes went into the data path before anyone
            // read the view.
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
                .task(id: reviewId) {
                    await viewModel.load(reviewId: reviewId, appState: appState)
                }

            if viewModel.isLoading && viewModel.envelope == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else if !viewModel.groups.isEmpty {
                header
                ForEach(viewModel.groups) { group in
                    changeCard(group)
                }
            } else if let message = viewModel.errorMessage {
                // Never silently empty again. A section that renders nothing on
                // failure is indistinguishable from one that was never asked to
                // load, which is exactly what made this take four attempts.
                unavailableNote(message)
            } else if reviewId == nil {
                unavailableNote(
                    NSLocalizedString(
                        "The list of changes is not available for this résumé.",
                        comment: "Shown when no review is associated with the optimization"
                    )
                )
            }
        }
    }

    private func unavailableNote(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("What changed")
                .font(.appHeadline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
            Text(message)
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
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

    private func changeCard(_ group: ReviewChangeGroupDTO) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ReviewSectionName.label(for: group.section))
                        .font(.appCaption.weight(.bold))
                        .foregroundStyle(AppColors.textTertiary)
                    Text(ReviewSectionName.localizedCopy(group.title))
                        .font(.appSubheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer(minLength: AppSpacing.xs)
                if viewModel.flaggedGroupIds.contains(group.id) {
                    checkThisLabel
                }
            }

            if !group.summary.isEmpty {
                Text(ReviewSectionName.localizedCopy(group.summary))
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
