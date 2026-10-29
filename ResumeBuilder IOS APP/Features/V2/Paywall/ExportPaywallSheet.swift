import StoreKit
import SwiftUI

enum ExportPaywallCopy {
    static let title: LocalizedStringKey = "Download more tailored CVs"
    static let body: LocalizedStringKey =
        "A free chatbot gives you text. Resumely gives you a ready PDF, right-to-left in Hebrew, in a clean template, with a before-and-after Match Score estimate."
    static let scoresStayFree: LocalizedStringKey = "Match Scores stay free and unlimited."
    static let bestValue: LocalizedStringKey = "Best value"
    static let planTitle: LocalizedStringKey = "Pro, unlimited PDF downloads (fair use)"
    static let renews: LocalizedStringKey = "Renews monthly until cancelled."
    static let planCapReached: LocalizedStringKey =
        "Your Pro plan reached its fair-use limit for this billing period. A pack lets you keep downloading until it resets."
    static let estimateFooter: LocalizedStringKey =
        "The Match Score is an estimate of how well your CV fits the job, not a hiring prediction."
    static let continueLabel: LocalizedStringKey = "Continue"
    static let restore: LocalizedStringKey = "Restore Purchases"
    static let terms: LocalizedStringKey = "Terms of Use"
    static let privacy: LocalizedStringKey = "Privacy Policy"
    static let close: LocalizedStringKey = "Close"
    static let loading: LocalizedStringKey = "Loading prices…"
    static let retry: LocalizedStringKey = "Try again"

    static func packTitle(credits: Int) -> LocalizedStringKey {
        switch credits {
        case 14: return "14 tailored CVs"
        default: return "5 tailored CVs"
        }
    }

    static func monthlyPrice(_ displayPrice: String) -> String {
        String(format: NSLocalizedString("%@ / month", comment: "Pro price per month, from StoreKit"), displayPrice)
    }

    static var nothingToRestore: String {
        NSLocalizedString(
            "Nothing to restore for this Apple ID. Your PDF downloads stay on your Resumely account.",
            comment: "Restore found no purchase"
        )
    }

    static var planAlreadyActive: String {
        NSLocalizedString(
            "Your Pro plan is already active on this account.",
            comment: "Restore found the Pro plan the account already has"
        )
    }

    static var restoreFailed: String {
        NSLocalizedString(
            "We couldn't restore right now. Check your connection and try again.",
            comment: "Restore failed"
        )
    }
}

/// One row of the sheet. `displayPrice` comes from StoreKit (`product.displayPrice`),
/// so the app never shows a typed price.
struct PackOffer: Identifiable, Equatable {
    let id: String
    /// Exports in a pack; 0 for Pro.
    let credits: Int
    let displayPrice: String
    var isSubscription = false

    /// The offer on sale for a StoreKit product ID, or nil.
    static func make(id: String, displayPrice: String) -> PackOffer? {
        if let credits = ResumelyProducts.exports(for: id) {
            return PackOffer(id: id, credits: credits, displayPrice: displayPrice)
        }
        if ResumelyProducts.isSubscription(id) {
            return PackOffer(id: id, credits: 0, displayPrice: displayPrice, isSubscription: true)
        }
        return nil
    }
}

/// Opens only after the server answered 402 for an export the user tapped, and
/// only once this account saw its own Match Score and a preview (pricing v2,
/// plan 3.1): never at launch, never as a banner. The 14-pack is listed first
/// and preselected, then the 5-pack, then Pro (plan A2). After a grant or a
/// restore it calls `onUnlocked`, and the caller runs the export the user
/// tapped without a second tap.
@Observable
@MainActor
final class ExportPaywallModel {
    enum Phase: Equatable {
        case loading
        case ready
        case unavailable
        case purchasing(productID: String)
        /// Paid or held, not granted yet: Ask to Buy waiting for approval, or a
        /// charged purchase whose server grant failed and is being retried.
        /// Nothing more can be bought from this sheet; the grant arrives in the
        /// background and resumes the export (Codex P1s on #207).
        case awaitingApproval(productID: String)
        /// Restore Purchases is running.
        case restoring
    }

    /// The store's background grant count when the wait began.
    private var grantCountAtWait = 0

    let optimizationId: String
    private(set) var phase: Phase = .loading
    private(set) var message: String?
    private(set) var offers: [PackOffer] = []
    /// The offer the Continue button buys. Starts on the first pack (the 14).
    private(set) var selectedID: String?
    private let store: StoreKitManager
    private let isFixture: Bool
    private let retryPendingPurchases: @MainActor () async -> Void
    private let loadStoreProducts: @MainActor () async throws -> Void
    private let restoreStorePurchases: @MainActor () async throws -> StoreKitManager.RestoreResult

    init(
        optimizationId: String,
        store: StoreKitManager = .shared,
        retryPendingPurchases: (@MainActor () async -> Void)? = nil,
        loadStoreProducts: (@MainActor () async throws -> Void)? = nil,
        restoreStorePurchases: (@MainActor () async throws -> StoreKitManager.RestoreResult)? = nil
    ) {
        self.optimizationId = optimizationId
        self.store = store
        self.isFixture = false
        self.retryPendingPurchases = retryPendingPurchases ?? { _ = await store.deliverPendingPurchases() }
        self.loadStoreProducts = loadStoreProducts ?? { try await store.loadProducts() }
        self.restoreStorePurchases = restoreStorePurchases ?? { try await store.restorePurchases() }
    }

    var selectedOffer: PackOffer? {
        offers.first { $0.id == selectedID }
    }

    func select(_ offer: PackOffer) {
        guard phase == .ready else { return }
        selectedID = offer.id
    }

    /// Hides Pro while this account already has it (the 402 then means the
    /// fair-use cap), keeping the selection on an offer that is shown.
    func hidePlan(_ hide: Bool) {
        guard hide else { return }
        offers.removeAll { $0.isSubscription }
        if selectedOffer == nil { selectedID = offers.first?.id }
        if offers.isEmpty, phase == .ready {
            phase = .unavailable
            message = StoreKitManagerError.productUnavailable.localizedDescription
        }
    }

    private func setOffers(_ newOffers: [PackOffer]) {
        offers = newOffers
        if selectedOffer == nil { selectedID = offers.first?.id }
    }

    /// The buyer, set by `load(for:)`; the waiting lock is per account.
    private var userId: UUID?

    /// Locks the sheet while this account has a purchase waiting (held or
    /// charged, not granted), from an earlier sheet or an earlier launch.
    /// Returns true when locked.
    @discardableResult
    private func applyPendingLock(for userId: UUID?) -> Bool {
        guard let waiting = store.pendingProductID(for: userId) else { return false }
        if case .awaitingApproval = phase {} else { grantCountAtWait = store.backgroundGrantCount }
        phase = .awaitingApproval(productID: waiting)
        message = StoreKitManagerError.grantPending.localizedDescription
        return true
    }

    #if DEBUG
    /// DEBUG smoke harness only: shows the sheet with sample prices and no StoreKit.
    init(optimizationId: String, fixtureOffers: [PackOffer]) {
        self.optimizationId = optimizationId
        self.store = .shared
        self.isFixture = true
        self.retryPendingPurchases = {}
        self.loadStoreProducts = {}
        self.restoreStorePurchases = { StoreKitManager.RestoreResult(deliveredGrant: false, plan: .noPlan) }
        self.phase = .ready
        setOffers(fixtureOffers)
    }
    #endif

    func load(for userId: UUID?) async {
        guard !isFixture else { return }
        self.userId = userId
        if applyPendingLock(for: userId) {
            // Launch delivery may have failed offline. Retry the existing
            // transaction on every reopen, keeping the lock against repurchase.
            await retryPendingPurchases()
            if approvalGranted { return }
        } else {
            phase = .loading
            message = nil
        }
        do {
            try await loadStoreProducts()
            setOffers(store.products.compactMap { PackOffer.make(id: $0.id, displayPrice: $0.displayPrice) })
            // Nothing this sheet can sell (for example only Pro loaded and Pro
            // is hidden): show Try again, never an empty "ready" sheet (Codex on #226).
            if offers.isEmpty { throw StoreKitManagerError.productUnavailable }
            // Every result is derived from the store's lock, so a failed load
            // and a retry can never unlock a waiting purchase (Codex P1). A grant
            // that landed during the load keeps the sheet waiting, so
            // `approvalGranted` stays true and the export resumes (second-model P1).
            if !applyPendingLock(for: userId), !approvalGranted { phase = .ready }
        } catch {
            if !applyPendingLock(for: userId), !approvalGranted {
                phase = .unavailable
                message = StoreKitManagerError.productUnavailable.localizedDescription
            }
        }
    }

    /// Returns true when the server granted the credits.
    /// True once a background grant (the approval) has arrived while waiting.
    var approvalGranted: Bool {
        if case .awaitingApproval = phase { return store.backgroundGrantCount > grantCountAtWait }
        return false
    }

    func buy(_ offer: PackOffer, account: PurchaseAccount?) async -> Bool {
        guard phase == .ready, !isFixture, store.pendingProductID(for: account?.userId) == nil,
              let product = store.products.first(where: { $0.id == offer.id }) else { return false }
        let analytics = AnalyticsService.shared
        guard let account else {
            message = StoreKitManagerError.accountRequired.localizedDescription
            return false
        }
        phase = .purchasing(productID: product.id)
        message = nil
        defer { if case .purchasing = phase { phase = .ready } }
        // A purchase paid earlier but not granted yet (offline, server error) is
        // delivered first, so nobody pays twice for the export they tapped.
        if await store.deliverPendingPurchases() != nil {
            return true
        }
        // That delivery failed and locked this account: do not sell again
        // until it is granted (second-model P1 on #207).
        if applyPendingLock(for: account.userId) { return false }
        analytics.track(.purchaseStarted(productId: product.id))
        // Taken before the purchase, so a background grant that lands while
        // StoreKit is still returning is not missed.
        grantCountAtWait = store.backgroundGrantCount
        do {
            switch try await store.purchase(product, account: account) {
            case .granted(let verification):
                analytics.track(.purchaseCompleted(
                    productId: product.id,
                    price: "\(product.price)",
                    currency: product.priceFormatStyle.currencyCode,
                    creditsGranted: verification.creditsGranted
                ))
                return true
            case .cancelled:
                analytics.track(.purchaseCancelled(productId: product.id))
            case .pending:
                analytics.track(.purchasePending(productId: product.id))
                phase = .awaitingApproval(productID: product.id)
                message = NSLocalizedString(
                    "Your purchase is waiting for approval. Your credits are added once it is approved.",
                    comment: "Ask to Buy pending"
                )
            }
        } catch StoreKitManagerError.grantPending {
            // Charged, not granted yet. StoreKitManager retries; stay locked so a
            // second tap cannot charge again, and resume when the grant lands.
            analytics.track(.purchaseFailed(productId: product.id, reason: "grant_pending"))
            message = StoreKitManagerError.grantPending.localizedDescription
            phase = .awaitingApproval(productID: product.id)
        } catch {
            let reason = (error as? StoreKitManagerError).map { "\($0)" } ?? "storekit_error"
            analytics.track(.purchaseFailed(productId: product.id, reason: reason))
            message = (error as? LocalizedError)?.errorDescription
                ?? StoreKitManagerError.purchaseFailed.localizedDescription
        }
        return false
    }

    /// Restore Purchases (App Store review 3.1.1). Returns true when the export
    /// the user tapped can now go ahead (Pro restored, or an unfinished
    /// purchase granted). `planAlreadyActive`: Pro was active before, so this
    /// 402 is its fair-use cap and finding the same plan again unlocks nothing
    /// (second-model on #226).
    func restore(account: PurchaseAccount?, planAlreadyActive: Bool = false) async -> Bool {
        guard !isFixture, phase == .ready || phase == .unavailable else { return false }
        guard account != nil else {
            message = StoreKitManagerError.accountRequired.localizedDescription
            return false
        }
        let previous = phase
        phase = .restoring
        message = nil
        defer { if phase == .restoring { phase = previous } }
        do {
            let result = try await restoreStorePurchases()
            if result.deliveredGrant || (result.unlocksExport && !planAlreadyActive) { return true }
            switch result.plan {
            case .recorded(let entitlement) where entitlement.active:
                message = ExportPaywallCopy.planAlreadyActive
            case .ownedByAnotherAccount:
                message = StoreKitManagerError.ownedByAnotherAccount.localizedDescription
            case .failed:
                message = ExportPaywallCopy.restoreFailed
            case .noAccount, .noPlan, .recorded:
                message = ExportPaywallCopy.nothingToRestore
            }
        } catch StoreKitError.userCancelled {
            // The user closed Apple's sign-in: nothing to say.
        } catch {
            message = ExportPaywallCopy.restoreFailed
        }
        return false
    }
}

struct ExportPaywallSheet: View {
    @Environment(LocalizationManager.self) private var localization
    @Environment(AppState.self) private var appState
    @State private var model: ExportPaywallModel
    /// Called after a successful grant, with the sheet still up; the caller closes it.
    let onUnlocked: () -> Void
    let onClose: () -> Void

    init(
        optimizationId: String,
        model: ExportPaywallModel? = nil,
        onUnlocked: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        _model = State(initialValue: model ?? ExportPaywallModel(optimizationId: optimizationId))
        self.onUnlocked = onUnlocked
        self.onClose = onClose
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppColors.accentTeal)
                        .accessibilityHidden(true)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(isBusy)
                    .accessibilityLabel(Text(ExportPaywallCopy.close))
                    .accessibilityIdentifier("paywall.close")
                }

                Text(ExportPaywallCopy.title)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(ExportPaywallCopy.body)
                        .foregroundStyle(AppColors.textSecondary)
                    Label(ExportPaywallCopy.scoresStayFree, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.textPrimary)
                }
                .font(.appSubheadline)
                .fixedSize(horizontal: false, vertical: true)

                if hasActivePlan {
                    Text(ExportPaywallCopy.planCapReached)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("paywall.capReached")
                }

                offersList

                if let message = model.message {
                    Text(message)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("paywall.message")
                }

                footer
            }
            .padding(AppSpacing.lg)
        }
        .screenBackground()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // A sheet does not inherit the app root's direction (lessons 2026-10-19).
        .environment(\.layoutDirection, localization.layoutDirection)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isBusy)
        .onChange(of: model.approvalGranted) { _, granted in
            if granted { onUnlocked() }
        }
        .onChange(of: model.offers) { _, _ in
            model.hidePlan(hasActivePlan)
        }
        .task {
            AnalyticsService.shared.track(.paywallShown(optimizationId: model.optimizationId, balance: appState.creditsBalance))
            await model.load(for: appState.purchaseAccount?.userId)
            model.hidePlan(hasActivePlan)
        }
    }

    /// Pro is already active, so this 402 means its fair-use cap.
    private var hasActivePlan: Bool {
        appState.subscription?.active == true
    }

    private var isBusy: Bool {
        switch model.phase {
        case .purchasing, .restoring: return true
        default: return false
        }
    }

    @ViewBuilder
    private var offersList: some View {
        switch model.phase {
        case .loading:
            HStack(spacing: AppSpacing.sm) {
                ProgressView()
                Text(ExportPaywallCopy.loading)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        case .unavailable:
            Button {
                Task { await model.load(for: appState.purchaseAccount?.userId) }
            } label: {
                Text(ExportPaywallCopy.retry)
                    .font(.appSubheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("paywall.retry")
        case .ready, .purchasing, .awaitingApproval, .restoring:
            VStack(spacing: AppSpacing.sm) {
                ForEach(model.offers) { offer in
                    offerRow(offer)
                }
                continueButton
            }
        }
    }

    private func offerRow(_ offer: PackOffer) -> some View {
        let isSelected = model.selectedID == offer.id
        return Button {
            model.select(offer)
        } label: {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? AppColors.accentTeal : AppColors.textTertiary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    if offer.isSubscription {
                        Text(ExportPaywallCopy.planTitle)
                            .font(.appSubheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(ExportPaywallCopy.renews)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Text(ExportPaywallCopy.packTitle(credits: offer.credits))
                            .font(.appSubheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        if offer.id == ResumelyProducts.exports14 {
                            Text(ExportPaywallCopy.bestValue)
                                .font(.appCaption.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 2)
                                .background(AppColors.accentTeal, in: Capsule())
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.sm)
                Text(offer.isSubscription ? ExportPaywallCopy.monthlyPrice(offer.displayPrice) : offer.displayPrice)
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.accentTeal)
                    .monospacedDigit()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .frame(minHeight: 56)
            .glassCard(cornerRadius: AppRadii.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.md)
                    .stroke(isSelected ? AppColors.accentTeal : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(model.phase != .ready)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(offer.isSubscription ? "paywall.pro" : "paywall.pack.\(offer.credits)")
    }

    private var continueButton: some View {
        let isBuying: Bool = {
            if case .purchasing = model.phase { return true }
            return false
        }()
        return Button {
            guard let offer = model.selectedOffer else { return }
            Task {
                if await model.buy(offer, account: appState.purchaseAccount) {
                    onUnlocked()
                }
            }
        } label: {
            Group {
                if isBuying {
                    ProgressView()
                } else {
                    Text(ExportPaywallCopy.continueLabel)
                }
            }
            .font(.appSubheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.accentTeal)
        .foregroundStyle(.black)
        .disabled(model.phase != .ready || model.selectedOffer == nil)
        .accessibilityIdentifier("paywall.continue")
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(ExportPaywallCopy.estimateFooter)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // Wraps to a column at large text sizes instead of truncating.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.md) { footerLinks }
                VStack(alignment: .leading, spacing: AppSpacing.sm) { footerLinks }
            }
            .font(.appCaption.weight(.semibold))
            .tint(AppColors.accentTeal)
        }
    }

    @ViewBuilder
    private var footerLinks: some View {
        Button {
            Task {
                if await model.restore(account: appState.purchaseAccount, planAlreadyActive: hasActivePlan) {
                    onUnlocked()
                }
            }
        } label: {
            if model.phase == .restoring {
                ProgressView()
            } else {
                Text(ExportPaywallCopy.restore)
            }
        }
        .disabled(!(model.phase == .ready || model.phase == .unavailable))
        .accessibilityIdentifier("paywall.restore")
        Link(destination: LegalLinks.termsURL(language: localization.language)) {
            Text(ExportPaywallCopy.terms)
        }
        Link(destination: LegalLinks.privacyURL(language: localization.language)) {
            Text(ExportPaywallCopy.privacy)
        }
    }
}

/// Presents the export paywall for the optimization a 402 named, and dismisses
/// it with `paywall_dismissed` when the user closes it without buying.
struct ExportPaywallPresenter: ViewModifier {
    @Environment(AppState.self) private var appState
    @Binding var optimizationId: String?
    let onUnlocked: () -> Void

    /// Set on a grant; the export runs from `onDismiss`, once the sheet is gone,
    /// so the share sheet it opens is not dropped mid-dismissal.
    @State private var unlockedPending = false

    func body(content: Content) -> some View {
        content.sheet(item: Binding(
            get: { optimizationId.map(PaywallItem.init) },
            set: { newValue in
                // Swiped away without buying.
                if newValue == nil, let dismissed = optimizationId {
                    AnalyticsService.shared.track(.paywallDismissed(optimizationId: dismissed, balance: appState.creditsBalance))
                }
                optimizationId = newValue?.id
            }
        ), onDismiss: {
            if unlockedPending {
                unlockedPending = false
                onUnlocked()
            }
        }) { item in
            ExportPaywallSheet(
                optimizationId: item.id,
                onUnlocked: {
                    unlockedPending = true
                    optimizationId = nil
                },
                onClose: {
                    AnalyticsService.shared.track(.paywallDismissed(optimizationId: item.id, balance: appState.creditsBalance))
                    optimizationId = nil
                }
            )
        }
    }

    private struct PaywallItem: Identifiable {
        let id: String
    }
}

extension View {
    func exportPaywall(optimizationId: Binding<String?>, onUnlocked: @escaping () -> Void) -> some View {
        modifier(ExportPaywallPresenter(optimizationId: optimizationId, onUnlocked: onUnlocked))
    }
}
