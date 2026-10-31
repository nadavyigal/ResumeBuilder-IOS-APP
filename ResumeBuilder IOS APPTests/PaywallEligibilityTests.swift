import StoreKit
import XCTest
@testable import ResumeBuilder_IOS_APP

// Pricing v2, S3: the paywall opens only after this account saw its own Match
// Score and a preview; it sells the 14-pack first, then the 5-pack, then Pro;
// Restore says what happened; Profile shows the plan in one glance.

@MainActor
final class PaywallEligibilityTests: XCTestCase {
    private func milestones() -> PaywallMilestones {
        PaywallMilestones(defaults: UserDefaults(suiteName: "paywall-milestones-\(UUID().uuidString)")!)
    }

    func testThePaywallWaitsForTheScoreAndThePreview() {
        let store = milestones()
        XCTAssertEqual(store.eligibility(userId: "u1"), .needsScore)

        store.markScoreSeen(userId: "u1")
        XCTAssertEqual(store.eligibility(userId: "u1"), .needsPreview)

        store.markPreviewSeen(userId: "u1")
        XCTAssertEqual(store.eligibility(userId: "u1"), .eligible)
    }

    func testMilestonesBelongToOneAccount() {
        let store = milestones()
        store.markScoreSeen(userId: "u1")
        store.markPreviewSeen(userId: "u1")
        XCTAssertEqual(store.eligibility(userId: "u2"), .needsScore)
        XCTAssertEqual(store.eligibility(userId: nil), .needsPreview)
    }

    func testAScreenWithNoScoreNeedsOnlyThePreview() {
        let store = milestones()
        XCTAssertEqual(store.eligibility(userId: "u1", requiresScore: false), .needsPreview)
        store.markPreviewSeen(userId: "u1")
        XCTAssertEqual(store.eligibility(userId: "u1", requiresScore: false), .eligible)
    }

    /// A preview that failed to render must not block buying the server PDF
    /// (Codex on #226).
    func testAFailedPreviewDoesNotBlockThePaywall() {
        let store = milestones()
        store.markScoreSeen(userId: "u1")
        XCTAssertEqual(store.eligibility(userId: "u1", requiresPreview: false), .eligible)
        XCTAssertEqual(store.eligibility(userId: "u1", requiresScore: false, requiresPreview: false), .eligible)
        XCTAssertEqual(store.eligibility(userId: "u2", requiresPreview: false), .needsScore, "the score rule still applies")
    }

    func testANoticeOnlyWhenThePaywallMustWait() {
        XCTAssertNil(PaywallEligibility.eligible.notice)
        XCTAssertNotNil(PaywallEligibility.needsScore.notice)
        XCTAssertNotNil(PaywallEligibility.needsPreview.notice)
    }

    func testAppStateMarksTheSignedInAccount() {
        let store = milestones()
        let appState = AppState()
        appState.session = AuthSession(accessToken: "t", refreshToken: "r", userId: "11111111-1111-4111-8111-111111111111", email: "a@example.com")

        appState.markMatchScoreSeen(store)
        appState.markPDFPreviewSeen(store)

        XCTAssertEqual(appState.paywallEligibility(store), .eligible)
        appState.session = nil
        appState.markMatchScoreSeen(store)
        XCTAssertEqual(appState.paywallEligibility(store), .needsPreview)
    }
}

/// `MainTabViewV2` keeps the Optimized tab mounted at zero opacity, so a score
/// panel can appear while the user is on Home (Codex on #226).
@MainActor
final class ScoreViewPolicyTests: XCTestCase {
    func testAHiddenTabRecordsNothing() {
        var policy = ScoreViewPolicy()
        XCTAssertEqual(policy.consume(panelShown: true, isActive: false, score: 70), .init())
    }

    func testBecomingActiveRecordsWhatTheHiddenTabHeldBack() {
        var policy = ScoreViewPolicy()
        _ = policy.consume(panelShown: true, isActive: false, score: 70)

        let outcome = policy.consume(panelShown: true, isActive: true, score: 70)

        XCTAssertEqual(outcome, .init(markSeen: true, trackedScore: 70))
    }

    func testTheScoreIsTrackedOncePerScreen() {
        var policy = ScoreViewPolicy()
        _ = policy.consume(panelShown: true, isActive: true, score: 70)

        let again = policy.consume(panelShown: true, isActive: true, score: 70)

        XCTAssertEqual(again, .init(markSeen: true, trackedScore: nil))
    }

    func testNoPanelRecordsNothing() {
        var policy = ScoreViewPolicy()
        XCTAssertEqual(policy.consume(panelShown: false, isActive: true, score: 70), .init())
    }

    func testAPanelWithNoNumberMarksSeenAndTracksTheScoreWhenItArrives() {
        var policy = ScoreViewPolicy()
        XCTAssertEqual(policy.consume(panelShown: true, isActive: true, score: nil), .init(markSeen: true))
        XCTAssertEqual(policy.consume(panelShown: true, isActive: true, score: 64), .init(markSeen: true, trackedScore: 64))
    }
}

@MainActor
final class PaywallOffersTests: XCTestCase {
    private let offers = [
        PackOffer(id: "resumely.exports.14", credits: 14, displayPrice: "$7.99"),
        PackOffer(id: "resumely.exports.5.v2", credits: 5, displayPrice: "$3.99"),
        PackOffer(id: "resumely.pro.monthly", credits: 0, displayPrice: "$9.99", isSubscription: true),
    ]

    func testOnlyProductsOnSaleBecomeOffers() {
        XCTAssertEqual(PackOffer.make(id: "resumely.exports.14", displayPrice: "$7.99"), offers[0])
        XCTAssertEqual(PackOffer.make(id: "resumely.exports.5.v2", displayPrice: "$3.99"), offers[1])
        XCTAssertEqual(PackOffer.make(id: "resumely.pro.monthly", displayPrice: "$9.99"), offers[2])
        for retired in ResumelyProducts.retiredPackIDs {
            XCTAssertNil(PackOffer.make(id: retired, displayPrice: "$1"))
        }
    }

    func testThe14PackIsPreselected() {
        let model = ExportPaywallModel(optimizationId: "o", fixtureOffers: offers)
        XCTAssertEqual(model.offers.map(\.id), ["resumely.exports.14", "resumely.exports.5.v2", "resumely.pro.monthly"])
        XCTAssertEqual(model.selectedID, "resumely.exports.14")

        model.select(offers[2])
        XCTAssertEqual(model.selectedOffer, offers[2])
    }

    func testAnActivePlanHidesProAndKeepsAShownSelection() {
        let model = ExportPaywallModel(optimizationId: "o", fixtureOffers: offers)
        model.select(offers[2])

        model.hidePlan(true)

        XCTAssertEqual(model.offers.map(\.id), ["resumely.exports.14", "resumely.exports.5.v2"])
        XCTAssertEqual(model.selectedID, "resumely.exports.14")
    }

    func testHidingProWithNoPackLeftShowsTryAgain() {
        let model = ExportPaywallModel(optimizationId: "o", fixtureOffers: [offers[2]])
        model.hidePlan(true)
        XCTAssertTrue(model.offers.isEmpty)
        XCTAssertEqual(model.phase, .unavailable)
        XCTAssertEqual(model.message, StoreKitManagerError.productUnavailable.localizedDescription)
    }

    /// A plan that ended while the sheet was hiding Pro (a credits reply, or a
    /// Restore that found nothing) must put the offer back (Codex on #226).
    func testAPlanThatEndedBringsProBack() {
        let model = ExportPaywallModel(optimizationId: "o", fixtureOffers: offers)
        model.hidePlan(true)

        model.hidePlan(false)

        XCTAssertEqual(model.offers.map(\.id), ["resumely.exports.14", "resumely.exports.5.v2", "resumely.pro.monthly"])
        XCTAssertEqual(model.selectedID, "resumely.exports.14")
    }

    func testProComingBackLeavesTryAgain() {
        let model = ExportPaywallModel(optimizationId: "o", fixtureOffers: [offers[2]])
        model.hidePlan(true)

        model.hidePlan(false)

        XCTAssertEqual(model.offers, [offers[2]])
        XCTAssertEqual(model.phase, .ready)
        XCTAssertNil(model.message)
    }

    /// App Store purchases are covered by Apple's standard EULA; the website
    /// Terms describe the web plan (founder decision 2026-10-30).
    func testThePaywallTermsLinkIsApplesStandardEULA() {
        XCTAssertEqual(LegalLinks.appleStandardEULA.absoluteString, "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        XCTAssertNotEqual(LegalLinks.appleStandardEULA, LegalLinks.termsURL(language: .english))
    }

    func testCopyNamesTheEstimateAndMakesNoClaim() {
        XCTAssertEqual(ExportPaywallCopy.packTitle(credits: 14), "14 tailored CVs")
        XCTAssertEqual(ExportPaywallCopy.packTitle(credits: 5), "5 tailored CVs")
        XCTAssertEqual(ExportPaywallCopy.monthlyPrice("$9.99"), "$9.99 / month")
        let english = [
            "Download more tailored CVs",
            "A free chatbot gives you text. Resumely gives you a ready PDF, right-to-left in Hebrew, in a clean template, with a before-and-after Match Score estimate.",
            "Match Scores stay free and unlimited.",
            "The Match Score is an estimate of how well your CV fits the job, not a hiring prediction.",
        ].joined(separator: " ")
        for banned in ["guarantee", "ATS score", "beat the ATS", "get hired", "Premium"] {
            XCTAssertFalse(english.localizedCaseInsensitiveContains(banned), banned)
        }
        XCTAssertTrue(english.contains("estimate"))
    }
}

/// A cancelled or expired Pro user must see the Pro offer again, so the sheet
/// asks the server before it trusts a cached plan (Codex on #226).
@MainActor
final class PaywallPlanFreshnessTests: XCTestCase {
    private let buyer = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private let onSale = [
        PackOffer(id: "resumely.exports.14", credits: 14, displayPrice: "$7.99"),
        PackOffer(id: "resumely.exports.5.v2", credits: 5, displayPrice: "$3.99"),
        PackOffer(id: "resumely.pro.monthly", credits: 0, displayPrice: "$9.99", isSubscription: true),
    ]

    private func model(onPriceLoad: @escaping @MainActor () -> Void = {}) -> ExportPaywallModel {
        let onSale = onSale
        return ExportPaywallModel(
            optimizationId: "o",
            store: StoreKitManager(defaults: UserDefaults(suiteName: "plan-fresh-\(UUID().uuidString)")!),
            retryPendingPurchases: {},
            loadStoreProducts: { onPriceLoad() },
            storeOffers: { onSale }
        )
    }

    func testAnEndedPlanKeepsProOnSale() async {
        let model = model()

        await model.load(for: buyer, refreshPlan: { false })

        XCTAssertEqual(model.offers, onSale)
        XCTAssertEqual(model.phase, .ready)
    }

    func testAPlanTheServerConfirmsHidesPro() async {
        let model = model()

        await model.load(for: buyer, refreshPlan: { true })

        XCTAssertEqual(model.offers.map(\.id), ["resumely.exports.14", "resumely.exports.5.v2"])
        XCTAssertEqual(model.phase, .ready)
    }

    func testTheServerAnswersBeforeThePricesShow() async {
        var steps: [String] = []
        let model = model(onPriceLoad: { steps.append("prices") })

        await model.load(for: buyer, refreshPlan: { steps.append("plan"); return false })

        XCTAssertEqual(steps, ["plan", "prices"])
    }

    func testTryAgainAsksTheServerAgain() async {
        let model = model()
        var asked = 0
        let refresh: @MainActor () async -> Bool = { asked += 1; return asked == 1 }

        await model.load(for: buyer, refreshPlan: refresh)
        await model.load(for: buyer, refreshPlan: refresh)

        XCTAssertEqual(asked, 2)
        XCTAssertEqual(model.offers, onSale, "the second answer says the plan ended")
    }

    /// Only Pro loaded and Pro is hidden: Try again, then a plan that ended
    /// must not leave the stale empty state.
    func testAPlanThatEndsAfterAnEmptySheetSellsProAgain() async {
        let onlyPro = [onSale[2]]
        let model = ExportPaywallModel(
            optimizationId: "o",
            store: StoreKitManager(defaults: UserDefaults(suiteName: "plan-fresh-\(UUID().uuidString)")!),
            retryPendingPurchases: {},
            loadStoreProducts: {},
            storeOffers: { onlyPro }
        )
        await model.load(for: buyer, refreshPlan: { true })
        XCTAssertEqual(model.phase, .unavailable)

        model.hidePlan(false)

        XCTAssertEqual(model.offers, onlyPro)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertNil(model.message)
    }

    /// Bringing Pro back must never unlock a purchase still waiting for its grant.
    func testProComingBackKeepsAWaitingPurchaseLocked() async {
        let store = StoreKitManager(defaults: UserDefaults(suiteName: "plan-fresh-\(UUID().uuidString)")!)
        store.setPendingLock(userId: buyer, productID: ResumelyProducts.exports5)
        let onlyPro = [onSale[2]]
        let model = ExportPaywallModel(
            optimizationId: "o",
            store: store,
            retryPendingPurchases: {},
            loadStoreProducts: {},
            storeOffers: { onlyPro }
        )
        await model.load(for: buyer, refreshPlan: { true })

        model.hidePlan(false)

        XCTAssertEqual(model.phase, .awaitingApproval(productID: ResumelyProducts.exports5))
    }

    /// The sheet's cap note follows the model, not the cached plan.
    func testTheCapNoteWaitsForTheServer() async {
        let model = model()
        XCTAssertFalse(model.isPlanHidden, "nothing is hidden until the server answers")

        await model.load(for: buyer, refreshPlan: { true })
        XCTAssertTrue(model.isPlanHidden)

        model.hidePlan(false)
        XCTAssertFalse(model.isPlanHidden)
    }
}

@MainActor
final class PaywallRestoreTests: XCTestCase {
    private let account = PurchaseAccount(userId: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!, token: "tok")

    private func model(_ restore: @escaping @MainActor () async throws -> StoreKitManager.RestoreResult) async -> ExportPaywallModel {
        let store = StoreKitManager(defaults: UserDefaults(suiteName: "restore-\(UUID().uuidString)")!)
        let model = ExportPaywallModel(
            optimizationId: "o",
            store: store,
            retryPendingPurchases: {},
            loadStoreProducts: {},
            restoreStorePurchases: restore
        )
        await model.load(for: account.userId)
        return model
    }

    private let active = SubscriptionEntitlement(active: true, productId: ResumelyProducts.proMonthly, expiresAt: nil)

    func testARestoredPlanResumesTheExport() async {
        let model = await model { .init(deliveredGrant: false, plan: .recorded(self.active)) }
        let unlocked = await model.restore(account: account)
        XCTAssertTrue(unlocked)
        XCTAssertNil(model.message)
    }

    func testRestoringThePlanThatHitItsCapDoesNotReopenThePaywall() async {
        let model = await model { .init(deliveredGrant: false, plan: .recorded(self.active)) }
        let unlocked = await model.restore(account: account, planAlreadyActive: true)
        XCTAssertFalse(unlocked)
        XCTAssertEqual(model.message, ExportPaywallCopy.planAlreadyActive)
    }

    func testARestoredUnfinishedPackResumesTheExport() async {
        let model = await model { .init(deliveredGrant: true, plan: .noPlan) }
        let unlocked = await model.restore(account: account)
        XCTAssertTrue(unlocked)
    }

    func testNothingToRestoreSaysSo() async {
        let model = await model { .init(deliveredGrant: false, plan: .noPlan) }
        let unlocked = await model.restore(account: account)
        XCTAssertFalse(unlocked)
        XCTAssertEqual(model.message, ExportPaywallCopy.nothingToRestore)
        XCTAssertEqual(model.phase, .unavailable, "restore returns the sheet to where it was")
    }

    func testAnotherAccountsPlanNamesTheOwner() async {
        let model = await model { .init(deliveredGrant: false, plan: .ownedByAnotherAccount) }
        _ = await model.restore(account: account)
        XCTAssertEqual(model.message, StoreKitManagerError.ownedByAnotherAccount.localizedDescription)
    }

    func testCancellingApplesSignInSaysNothing() async {
        let model = await model { throw StoreKitError.userCancelled }
        let unlocked = await model.restore(account: account)
        XCTAssertFalse(unlocked)
        XCTAssertNil(model.message)
    }

    func testAGuestIsAskedForAnAccount() async {
        let model = await model { XCTFail("must not restore without an account"); return .init(deliveredGrant: false, plan: .noPlan) }
        let unlocked = await model.restore(account: nil)
        XCTAssertFalse(unlocked)
        XCTAssertEqual(model.message, StoreKitManagerError.accountRequired.localizedDescription)
    }
}

@MainActor
final class PlanSummaryTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    func testWithoutProItCountsTheDownloadsLeft() {
        XCTAssertEqual(PlanSummary.make(subscription: nil, balance: 3, locale: english).headline, "3 PDF downloads left")
        XCTAssertEqual(PlanSummary.make(subscription: nil, balance: 1, locale: english).headline, "1 PDF download left")
        let expired = SubscriptionStatus(active: false, productId: ResumelyProducts.proMonthly)
        let summary = PlanSummary.make(subscription: expired, balance: 0, locale: english)
        XCTAssertEqual(summary.headline, "0 PDF downloads left")
        XCTAssertFalse(summary.canManageSubscription)
    }

    func testProShowsItsRenewalAndFairUse() {
        let pro = SubscriptionStatus(
            active: true,
            productId: ResumelyProducts.proMonthly,
            expiresAt: "2026-11-29T10:00:00+00:00",
            autoRenew: true,
            periodExports: 12,
            periodCap: 40
        )
        let summary = PlanSummary.make(subscription: pro, balance: 2, locale: english)
        XCTAssertEqual(summary.headline, "Pro, renews Nov 29, 2026")
        XCTAssertEqual(summary.detail, "12 of 40 PDF downloads used this period (fair use)")
        XCTAssertTrue(summary.canManageSubscription)
    }

    func testCancelledProShowsWhenItEnds() {
        let pro = SubscriptionStatus(active: true, expiresAt: "2026-11-29T10:00:00+00:00", autoRenew: false)
        XCTAssertEqual(PlanSummary.make(subscription: pro, balance: 0, locale: english).headline, "Pro until Nov 29, 2026")
    }
}
