import Foundation

/// When the export paywall may open (pricing v2, plan 3.1). The server decides
/// whether an export is paid (a 402); the app shows the paywall only once this
/// account has seen its own Match Score and a PDF preview. A sample score never
/// counts (S4 does not mark it).
enum PaywallEligibility: Equatable {
    case eligible
    case needsScore
    case needsPreview
}

/// "Seen its own score" and "seen a preview", per user id, on this device.
/// Kept across sign-out so the same account is not asked again.
struct PaywallMilestones {
    private static let scoreKey = "paywall_seen_score_user_ids"
    private static let previewKey = "paywall_seen_preview_user_ids"
    var defaults: UserDefaults = .standard

    func markScoreSeen(userId: String) {
        add(userId, to: Self.scoreKey)
    }

    func markPreviewSeen(userId: String) {
        add(userId, to: Self.previewKey)
    }

    /// `requiresScore: false` on a screen that has no score to show (the
    /// design preview), and `requiresPreview: false` when the preview failed
    /// to render, so the rule can never leave a 402 with nothing to do: the
    /// server PDF is still there to buy (Codex on #226).
    func eligibility(userId: String?, requiresScore: Bool = true, requiresPreview: Bool = true) -> PaywallEligibility {
        guard let userId else { return requiresPreview ? .needsPreview : .eligible }
        if requiresScore, !ids(Self.scoreKey).contains(userId) { return .needsScore }
        if requiresPreview, !ids(Self.previewKey).contains(userId) { return .needsPreview }
        return .eligible
    }

    private func ids(_ key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    private func add(_ userId: String, to key: String) {
        var current = ids(key)
        guard current.insert(userId).inserted else { return }
        defaults.set(Array(current), forKey: key)
    }
}

extension PaywallEligibility {
    /// Shown instead of the paywall when the rule is not met yet.
    var notice: String? {
        switch self {
        case .eligible:
            return nil
        case .needsScore:
            return NSLocalizedString(
                "Check your Match Score on this screen first, then tap Export again.",
                comment: "Export refused before the user saw their own Match Score"
            )
        case .needsPreview:
            return NSLocalizedString(
                "Your preview is still loading. Look it over, then tap Export again.",
                comment: "Export refused before the user saw the PDF preview"
            )
        }
    }
}

extension AppState {
    @MainActor
    func markMatchScoreSeen(_ milestones: PaywallMilestones = PaywallMilestones()) {
        guard let userId = session?.userId else { return }
        milestones.markScoreSeen(userId: userId)
    }

    @MainActor
    func markPDFPreviewSeen(_ milestones: PaywallMilestones = PaywallMilestones()) {
        guard let userId = session?.userId else { return }
        milestones.markPreviewSeen(userId: userId)
    }

    @MainActor
    func paywallEligibility(
        requiresScore: Bool = true,
        requiresPreview: Bool = true,
        _ milestones: PaywallMilestones = PaywallMilestones()
    ) -> PaywallEligibility {
        milestones.eligibility(userId: session?.userId, requiresScore: requiresScore, requiresPreview: requiresPreview)
    }
}
