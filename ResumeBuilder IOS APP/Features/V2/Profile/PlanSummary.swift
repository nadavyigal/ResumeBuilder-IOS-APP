import Foundation

/// What the Profile "Plan" row says (pricing v2, S3). The server's numbers,
/// worded for one glance: Pro and its date, or the PDF downloads left.
struct PlanSummary: Equatable {
    let headline: String
    let detail: String?
    /// Pro is active, so Apple's Manage Subscription sheet is offered.
    let canManageSubscription: Bool

    static func make(subscription: SubscriptionStatus?, balance: Int, locale: Locale) -> PlanSummary {
        guard let subscription, subscription.active else {
            let headline = balance == 1
                ? NSLocalizedString("1 PDF download left", comment: "Profile plan row, one export credit")
                : String(format: NSLocalizedString("%d PDF downloads left", comment: "Profile plan row, export credits"), balance)
            return PlanSummary(headline: headline, detail: nil, canManageSubscription: false)
        }

        let headline: String
        if let expiry = subscription.expiryDate {
            let date = expiry.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
            headline = subscription.autoRenew == false
                ? String(format: NSLocalizedString("Pro until %@", comment: "Profile plan row, Pro cancelled, ends on date"), date)
                : String(format: NSLocalizedString("Pro, renews %@", comment: "Profile plan row, Pro renews on date"), date)
        } else {
            headline = NSLocalizedString("Pro", comment: "Profile plan row, Pro with no date")
        }

        var detail: String?
        if let used = subscription.periodExports, let cap = subscription.periodCap {
            detail = String(
                format: NSLocalizedString("%1$d of %2$d PDF downloads used this period (fair use)", comment: "Profile plan row, Pro fair-use count"),
                used, cap
            )
        }
        return PlanSummary(headline: headline, detail: detail, canManageSubscription: true)
    }
}
