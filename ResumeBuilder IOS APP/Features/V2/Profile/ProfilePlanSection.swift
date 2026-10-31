import StoreKit
import SwiftUI

/// The Profile "Plan" row (pricing v2, S3): Pro and its date, or the PDF
/// downloads left, with Restore Purchases and Apple's Manage Subscription
/// sheet. Numbers come from the server (`GET /api/v1/credits`).
struct ProfilePlanSection: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalizationManager.self) private var localization
    @State private var showManageSubscription = false
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    var body: some View {
        let summary = PlanSummary.make(
            subscription: appState.subscription,
            balance: appState.creditsBalance,
            locale: localization.locale
        )
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let detail = summary.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
                Text("Match Scores stay free and unlimited.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.plan")

            if summary.canManageSubscription {
                divider
                Button { showManageSubscription = true } label: {
                    row(icon: "gearshape.fill", label: "Manage subscription")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.manageSubscription")
            }

            divider
            Button { Task { await restorePurchases() } } label: {
                row(icon: "arrow.clockwise", label: "Restore Purchases")
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)
            .accessibilityIdentifier("profile.restore")

            if let restoreMessage {
                Text(restoreMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .bottom], 14)
            }
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .task { await appState.refreshCredits() }
    }

    private var divider: some View {
        Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 14)
    }

    /// Same look as the other Profile rows.
    private func row(icon: String, label: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.accentBlue.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accentBlue)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(14)
    }

    @MainActor
    private func restorePurchases() async {
        isRestoring = true
        restoreMessage = nil
        defer { isRestoring = false }
        do {
            let result = try await StoreKitManager.shared.restorePurchases()
            await appState.refreshCredits()
            if result.deliveredGrant {
                restoreMessage = NSLocalizedString("Your purchase is restored.", comment: "Restore delivered an unfinished purchase")
                return
            }
            switch result.plan {
            case .ownedByAnotherAccount:
                restoreMessage = StoreKitManagerError.ownedByAnotherAccount.localizedDescription
            case .failed:
                restoreMessage = ExportPaywallCopy.restoreFailed
            case .recorded(let entitlement) where entitlement.active:
                restoreMessage = NSLocalizedString("Your Pro plan is restored.", comment: "Restore found an active Pro plan")
            case .noAccount:
                restoreMessage = StoreKitManagerError.accountRequired.localizedDescription
            case .noPlan, .recorded:
                restoreMessage = ExportPaywallCopy.nothingToRestore
            }
        } catch StoreKitError.userCancelled {
            // The user closed Apple's sign-in: nothing to say.
        } catch {
            restoreMessage = ExportPaywallCopy.restoreFailed
        }
    }
}
