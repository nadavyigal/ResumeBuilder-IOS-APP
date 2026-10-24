import StoreKit
import SwiftUI

enum ExportPaywallCopy {
    static let title: LocalizedStringKey = "Export your tailored résumé"
    static let whatACreditBuys: LocalizedStringKey =
        "One credit exports one tailored résumé, in any format, as often as you need."
    static let neverExpire: LocalizedStringKey = "Credits never expire."
    static let restore: LocalizedStringKey =
        "Credits stay on your account. Sign in to the same account on another device to use them."
    static let close: LocalizedStringKey = "Close"
    static let loading: LocalizedStringKey = "Loading prices…"
    static let retry: LocalizedStringKey = "Try again"

    static func packTitle(credits: Int) -> LocalizedStringKey {
        switch credits {
        case 1: return "1 tailored export"
        case 5: return "5 tailored exports"
        default: return "10 tailored exports"
        }
    }
}

/// One row of the sheet. `displayPrice` comes from StoreKit (`product.displayPrice`),
/// so the app never shows a typed price.
struct PackOffer: Identifiable, Equatable {
    let id: String
    let credits: Int
    let displayPrice: String
}

/// Opens only after the server answered 402 `export_credits_required` for an
/// export the user tapped (StoreKit spec 10.1): never at launch, never as a
/// banner, no "Premium" wording (EXD-018). After a grant it calls `onUnlocked`,
/// and the caller runs the export the user tapped without a second tap.
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
    }

    /// The store's background grant count when the wait began.
    private var grantCountAtWait = 0

    let optimizationId: String
    private(set) var phase: Phase = .loading
    private(set) var message: String?
    private(set) var offers: [PackOffer] = []
    private let store: StoreKitManager
    private let isFixture: Bool
    private let retryPendingPurchases: @MainActor () async -> Void
    private let loadStoreProducts: @MainActor () async throws -> Void

    init(
        optimizationId: String,
        store: StoreKitManager = .shared,
        retryPendingPurchases: (@MainActor () async -> Void)? = nil,
        loadStoreProducts: (@MainActor () async throws -> Void)? = nil
    ) {
        self.optimizationId = optimizationId
        self.store = store
        self.isFixture = false
        self.retryPendingPurchases = retryPendingPurchases ?? { _ = await store.deliverPendingPurchases() }
        self.loadStoreProducts = loadStoreProducts ?? { try await store.loadProducts() }
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
        self.offers = fixtureOffers
        self.phase = .ready
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
            offers = store.products.compactMap { product in
                ExportCreditProducts.credits(for: product.id).map {
                    PackOffer(id: product.id, credits: $0, displayPrice: product.displayPrice)
                }
            }
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
                    .disabled(isPurchasing)
                    .accessibilityLabel(Text(ExportPaywallCopy.close))
                    .accessibilityIdentifier("paywall.close")
                }

                Text(ExportPaywallCopy.title)
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(ExportPaywallCopy.whatACreditBuys)
                    Text(ExportPaywallCopy.neverExpire)
                }
                .font(.appSubheadline)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                packs

                if let message = model.message {
                    Text(message)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("paywall.message")
                }

                Text(ExportPaywallCopy.restore)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.lg)
        }
        .screenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // A sheet does not inherit the app root's direction (lessons 2026-10-19).
        .environment(\.layoutDirection, localization.layoutDirection)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isPurchasing)
        .onChange(of: model.approvalGranted) { _, granted in
            if granted { onUnlocked() }
        }
        .task {
            AnalyticsService.shared.track(.paywallShown(optimizationId: model.optimizationId, balance: appState.creditsBalance))
            await model.load(for: appState.purchaseAccount?.userId)
        }
    }

    private var isPurchasing: Bool {
        if case .purchasing = model.phase { return true }
        return false
    }

    @ViewBuilder
    private var packs: some View {
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
        case .ready, .purchasing, .awaitingApproval:
            VStack(spacing: AppSpacing.sm) {
                ForEach(model.offers) { offer in
                    packRow(offer)
                }
            }
        }
    }

    private func packRow(_ offer: PackOffer) -> some View {
        let isBuyingThis = model.phase == .purchasing(productID: offer.id)
        return Button {
            Task {
                if await model.buy(offer, account: appState.purchaseAccount) {
                    onUnlocked()
                }
            }
        } label: {
            HStack {
                Text(ExportPaywallCopy.packTitle(credits: offer.credits))
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                if isBuyingThis {
                    ProgressView()
                } else {
                    Text(offer.displayPrice)
                        .font(.appSubheadline.weight(.semibold))
                        .foregroundStyle(AppColors.accentTeal)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 56)
            .glassCard(cornerRadius: AppRadii.md)
        }
        .buttonStyle(.plain)
        .disabled(model.phase != .ready)
        .accessibilityIdentifier("paywall.pack.\(offer.credits)")
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
