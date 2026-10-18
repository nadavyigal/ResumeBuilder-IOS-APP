import SwiftUI

/// Copy for the "Add only if true" sheet. The keys are the English source text and
/// `Resources/Localizable.xcstrings` holds the Hebrew, the same pattern as
/// `UploadCardCopy`: `LocalizedStringKey`, so a language switch re-renders.
/// Wording follows the web review page (`dashboard.optimization.review.changes.confirm`).
enum AddOnlyIfTrueCopy {
    static let title: LocalizedStringKey = "Add only if true"
    static let intro: LocalizedStringKey =
        "These lines match the job, but your résumé does not say them. Add only what is true for you."
    static let question: LocalizedStringKey = "This line uses the job's words. Is it true for you?"
    static let now: LocalizedStringKey = "Now it says"
    static let nowEmpty: LocalizedStringKey = "Not on your résumé"
    static let withLine: LocalizedStringKey = "If you confirm"
    static let add: LocalizedStringKey = "Yes, add it"
    static let remove: LocalizedStringKey = "Don't add"
    static let continueAction: LocalizedStringKey = "Continue to my résumé"
    static let cancel: LocalizedStringKey = "Cancel"
    /// Catalog key of `Text("+\(points) pts")`, already translated for the fit check.
    static let gainFormat = "+%lld pts"

    static let all: [LocalizedStringKey] = [title, intro, question, now, nowEmpty, withLine, add, remove, continueAction, cancel]
}

/// A review whose "Add only if true" claims wait for the user before anything is applied.
struct PendingPhraseConfirmation: Identifiable {
    let reviewId: String
    let envelope: OptimizationReviewEnvelope

    var id: String { reviewId }
    var claims: [ReviewChangeGroupDTO] { ConfirmPhraseSelection.claims(in: envelope) }
}

/// G2b: the job-post lines the optimizer wrote and the web guard held back because
/// the résumé never says them. Every one starts unselected; only the user can add
/// one. Continue applies all the other changes plus the lines the user confirmed.
struct AddOnlyIfTrueView: View {
    let claims: [ReviewChangeGroupDTO]
    /// Set after a failed apply; the choices stay and Continue tries again.
    var errorMessage: String? = nil
    var isApplying: Bool = false
    let onContinue: (Set<String>) -> Void
    let onCancel: () -> Void

    @State private var confirmed: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(AddOnlyIfTrueCopy.intro)
                        .font(.appSubheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(claims) { group in
                        if let claim = group.confirm {
                            claimCard(id: group.id, claim: claim)
                        }
                    }

                    if let errorMessage {
                        Text(verbatim: errorMessage)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.accentViolet)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("addOnlyIfTrue.error")
                    }

                    GradientButton(title: AddOnlyIfTrueCopy.continueAction, isLoading: isApplying) {
                        guard !isApplying else { return }
                        onContinue(confirmed)
                    }
                    .padding(.top, AppSpacing.sm)
                    .accessibilityIdentifier("addOnlyIfTrue.continue")
                }
                .padding(AppSpacing.lg)
            }
            .screenBackground()
            .navigationTitle(AddOnlyIfTrueCopy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AddOnlyIfTrueCopy.cancel, action: onCancel)
                        .disabled(isApplying)
                }
            }
        }
        // The design tokens are light-on-dark, as on the fit check sheet.
        .preferredColorScheme(.dark)
    }

    private func claimCard(id: String, claim: ReviewConfirmClaimDTO) -> some View {
        let isAdded = confirmed.contains(id)
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(AddOnlyIfTrueCopy.question)
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.xs)
                if let gain = claim.estimatedGain, gain > 0 {
                    Text("+\(gain) pts")
                        .font(.appCaption.weight(.bold))
                        .foregroundStyle(AppColors.accentTeal)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(AppColors.accentTeal.opacity(0.14), in: Capsule())
                }
            }

            excerpt(label: AddOnlyIfTrueCopy.now, text: claim.kept, emptyText: AddOnlyIfTrueCopy.nowEmpty, highlighted: false)
            excerpt(label: AddOnlyIfTrueCopy.withLine, text: claim.proposed, emptyText: nil, highlighted: true)

            Button {
                if isAdded { confirmed.remove(id) } else { confirmed.insert(id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAdded ? "xmark" : "checkmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                    Text(isAdded ? AddOnlyIfTrueCopy.remove : AddOnlyIfTrueCopy.add)
                        .font(.appSubheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .foregroundStyle(isAdded ? AppColors.textSecondary : AppColors.textPrimary)
                .background(
                    isAdded ? AppColors.glassTint : AppColors.accentViolet.opacity(0.35),
                    in: RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addOnlyIfTrue.toggle.\(id)")
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                .stroke(isAdded ? AppColors.accentTeal.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }

    private func excerpt(label: LocalizedStringKey, text: String?, emptyText: LocalizedStringKey?, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.appCaption.weight(.bold))
                .foregroundStyle(highlighted ? AppColors.accentTeal : AppColors.textTertiary)
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Résumé text: shown verbatim, never looked up in the catalog.
                Text(verbatim: text)
                    .font(.appCaption)
                    .foregroundStyle(highlighted ? AppColors.textPrimary : AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let emptyText {
                Text(emptyText)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(
            highlighted ? AppColors.accentTeal.opacity(0.08) : Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous)
        )
    }
}
