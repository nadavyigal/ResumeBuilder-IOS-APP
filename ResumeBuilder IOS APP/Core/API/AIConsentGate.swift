import Foundation
import SwiftUI
import UIKit

/// Thrown instead of sending when the user has not agreed to OpenAI processing.
enum AIConsentError: Error, LocalizedError, Equatable {
    case declined

    var errorDescription: String? {
        NSLocalizedString(
            "Nothing was sent. To check your résumé, Resumely needs your OK to send it to OpenAI.",
            comment: "Shown when the user declines the AI consent sheet"
        )
    }
}

extension Endpoint {
    /// POSTs to these routes put résumé, job or chat text in front of OpenAI,
    /// directly or through scoring embeddings. Traced from the web routes on
    /// 2026-10-19 (`src/app/api/**/route.ts` to `src/lib/openai.ts`,
    /// `ats/utils/embeddings.ts`, `chat-manager`, `expert-workflows`,
    /// `ats/amendment-generator`).
    ///
    /// Left out on purpose: reads (GET), `convertAnonymousSession` (sends only a
    /// session id to re-link work the guest already agreed to send),
    /// `designRenderPreview` and `download` (type-only imports, no model call).
    nonisolated var sendsPersonalDataToAI: Bool {
        switch self {
        case .publicATSCheck, .atsScore, .atsRescan, .optimize, .uploadResume,
             .refineSection, .chatSend, .chatApproveChange,
             .expertWorkflowRunPost, .expertWorkflowApply, .applicationExpertReports,
             .optimizationReviewApply, .keywordSuggestionPreview:
            return true
        default:
            return false
        }
    }

    /// Analytics `source` for the consent events. No ids, no user content.
    nonisolated var aiConsentSource: String {
        switch self {
        case .publicATSCheck: return "public_ats_check"
        case .atsScore: return "ats_score"
        case .atsRescan: return "ats_rescan"
        case .optimize: return "optimize"
        case .uploadResume: return "upload_resume"
        case .refineSection: return "refine_section"
        case .chatSend: return "chat_send"
        case .chatApproveChange: return "chat_approve_change"
        case .expertWorkflowRunPost: return "expert_workflow_run"
        case .expertWorkflowApply: return "expert_workflow_apply"
        case .applicationExpertReports: return "expert_reports"
        case .optimizationReviewApply: return "optimization_review_apply"
        case .keywordSuggestionPreview: return "keyword_suggestion_preview"
        default: return "other"
        }
    }
}

/// Decides whether a send to an OpenAI-backed endpoint may go ahead. `APIClient`
/// and `StreamingClient` ask it before every such POST, so no screen can send
/// without consent, including chat and refine on a restored optimization.
struct AIConsentGate: Sendable {
    let allows: @Sendable (Endpoint) async -> Bool

    static let live = AIConsentGate { endpoint in
        await AIConsentCenter.shared.ensureConsent(source: endpoint.aiConsentSource)
    }

    /// For tests that exercise a gated endpoint against a stubbed session.
    static let allowAll = AIConsentGate { _ in true }
    static let denyAll = AIConsentGate { _ in false }

    /// Throws `AIConsentError.declined` when `endpoint` needs consent and the
    /// user does not give it. Endpoints that send nothing to AI pass straight through.
    func require(_ endpoint: Endpoint) async throws {
        guard endpoint.sendsPersonalDataToAI else { return }
        guard await allows(endpoint) else { throw AIConsentError.declined }
    }
}

@MainActor
protocol AIConsentPresenting: AnyObject {
    /// Shows the consent sheet and calls `completion` once, after it has fully
    /// closed: `true` for "Agree and continue", `false` for "Not now" or a swipe.
    func present(completion: @escaping @MainActor (Bool) -> Void)
}

/// Asks once per identity and remembers the answer. Concurrent requests share
/// one sheet.
@MainActor
final class AIConsentCenter {
    static let shared = AIConsentCenter()

    /// The signed-in user's id, or nil. Set by the app root to read `AppState`.
    var userIdProvider: @MainActor () -> String? = { nil }
    var presenter: any AIConsentPresenting
    private let defaults: UserDefaults
    /// A send waiting on the open sheet, with the identity and generation it was
    /// asked for. The answer only goes to waiters it belongs to (Codex on #217).
    private struct Waiter {
        let identity: String
        let generation: Int
        let source: String
        let continuation: CheckedContinuation<Bool, Never>
    }
    private var waiting: [Waiter] = []
    private var sheetIsOpen = false
    /// Bumped by `clearAll`. A sheet that was open across a sign-out may still
    /// be answered; its yes must not be recorded for the identity that left.
    private var generation = 0
    /// The anonymous user id that took over from `guest` in this launch. A sheet
    /// opened as a guest and answered after that session landed belongs to it.
    private var anonymousSuccessor: String?

    init(defaults: UserDefaults = .standard, presenter: (any AIConsentPresenting)? = nil) {
        self.defaults = defaults
        self.presenter = presenter ?? UIKitAIConsentPresenter()
    }

    var currentStore: AIConsentStore {
        AIConsentStore(identity: AIConsentStore.identity(forUserId: userIdProvider()), defaults: defaults)
    }

    /// Posts the grant for an identity that already has a local yes. Returns true
    /// when the server stored it. A guest has no user id, so this is a no-op for them.
    var serverRecorder: (@MainActor (AIConsentStore) async -> Bool)?

    var hasConsented: Bool { currentStore.hasConsented }

    func flushServerRecordIfNeeded() async {
        let store = currentStore
        await flushServerRecord(for: store)
    }

    private func flushServerRecord(for store: AIConsentStore) async {
        guard store.needsServerRecord, let serverRecorder else { return }
        let askedGeneration = generation
        // A sign-out during the request wiped this store. Marking it recorded
        // now would stop that identity's next yes from reaching the server.
        if await serverRecorder(store), generation == askedGeneration {
            store.markServerRecorded()
        }
    }

    func ensureConsent(source: String) async -> Bool {
        let store = currentStore
        if store.hasConsented {
            let consentedGeneration = generation
            await flushServerRecord(for: store)
            // A sign-out during the record request cleared this consent: do not send.
            return generation == consentedGeneration
        }
        let askedGeneration = generation
        return await withCheckedContinuation { continuation in
            waiting.append(Waiter(identity: store.identity, generation: askedGeneration, source: source, continuation: continuation))
            guard !sheetIsOpen else { return }
            sheetIsOpen = true
            AnalyticsService.shared.track(.aiConsentShown(source: source))
            presenter.present { [weak self] answer in
                guard let self else { return }
                Task { @MainActor in
                    // Checked here, not when the sheet answered: a sign-out
                    // before this task runs voids the answer too, or the
                    // cleared consent would be recorded again (Codex on 18eadd3).
                    let agreed = answer && self.generation == askedGeneration
                    var recorded = store
                    if agreed {
                        store.recordConsent()
                        if store.identity == AIConsentStore.guestIdentity,
                           let successor = self.anonymousSuccessor {
                            AIConsentStore.carryGuestConsent(to: successor, defaults: self.defaults)
                            recorded = AIConsentStore(identity: successor, defaults: self.defaults)
                        }
                        await self.flushServerRecord(for: recorded)
                        AnalyticsService.shared.track(.aiConsentAccepted(source: source))
                    } else {
                        AnalyticsService.shared.track(.aiConsentDeclined(source: source))
                    }
                    // Check again after the await: a sign-out during the server
                    // record also voids the answer.
                    let stillAgreed = agreed && self.generation == askedGeneration
                    self.sheetIsOpen = false
                    let resumed = self.waiting
                    self.waiting = []
                    for waiter in resumed {
                        let belongs = waiter.generation == askedGeneration
                            && (waiter.identity == store.identity || waiter.identity == recorded.identity)
                        if belongs {
                            waiter.continuation.resume(returning: stillAgreed)
                        } else if waiter.generation != self.generation
                                    || waiter.identity != self.currentStore.identity {
                            // Its identity signed out, or is no longer the one
                            // signed in: nothing it asked for may be sent, and
                            // someone else's answer must not stand in for it
                            // (Codex on 123144e).
                            waiter.continuation.resume(returning: false)
                        } else {
                            // Joined for the identity signed in now while another
                            // identity's sheet was open: ask for its own answer.
                            Task { @MainActor in
                                waiter.continuation.resume(returning: await self.ensureConsent(source: waiter.source))
                            }
                        }
                    }
                }
            }
        }
    }

    /// A new anonymous session on this device, with no sign-in, takes over the
    /// guest's answer (#204): the guest agreed before the session existed, and
    /// is the same person. Called only from the anonymous sign-in path; a real
    /// account never takes a guest's yes (5.1.2(i), #200).
    func carryGuestConsent(toAnonymousUserId userId: String) {
        let identity = AIConsentStore.identity(forUserId: userId)
        guard identity != AIConsentStore.guestIdentity else { return }
        anonymousSuccessor = identity
        AIConsentStore.carryGuestConsent(to: identity, defaults: defaults)
    }

    /// Sign-out and account deletion: forget every answer, and void any sheet
    /// still open so its yes is not recorded afterwards.
    func clearAll() {
        generation &+= 1
        anonymousSuccessor = nil
        AIConsentStore.clearAll(defaults: defaults)
    }
}

/// Presents `AIConsentSheet` over whatever is on top (a sheet, a full-screen
/// cover, a pushed screen), which a SwiftUI `.sheet` on one view cannot do.
///
/// `completion` is called exactly once, however the sheet ends: a button, a
/// swipe, a dismissal from above (an ancestor modal closed by code, a root swap
/// after sign-out), or a presentation that never happened. Missing one of those
/// would leave `AIConsentCenter`'s waiters queued and hang every later gated
/// send until relaunch (CodeRabbit on PR #200).
@MainActor
final class UIKitAIConsentPresenter: NSObject, AIConsentPresenting, UIAdaptivePresentationControllerDelegate {
    private var completion: (@MainActor (Bool) -> Void)?
    private weak var host: UIViewController?
    /// Set by a button before the sheet closes, so the "gone" signal that fires
    /// during that dismissal reports the user's choice, not a decline.
    private var chosenAnswer: Bool?
    private let topViewController: @MainActor () -> UIViewController?

    init(topViewController: (@MainActor () -> UIViewController?)? = nil) {
        self.topViewController = topViewController ?? { UIKitAIConsentPresenter.keyWindowTopViewController() }
        super.init()
    }

    /// True while a sheet is on screen. For tests.
    var isPresentingSheet: Bool { host?.presentingViewController != nil }

    func present(completion: @escaping @MainActor (Bool) -> Void) {
        guard let top = topViewController() else {
            completion(false)
            return
        }
        self.completion = completion
        chosenAnswer = nil
        let localization = LocalizationManager.shared
        let sheet = AIConsentSheet(
            onAgree: { [weak self] in self?.close(agreed: true) },
            onNotNow: { [weak self] in self?.close(agreed: false) }
        )
        .environment(localization)
        .environment(\.locale, localization.locale)
        let host = AIConsentHostingController(rootView: AnyView(sheet))
        host.overrideUserInterfaceStyle = .dark
        host.onGone = { [weak self] in self?.sheetIsGone() }
        if let sheetController = host.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
        }
        host.presentationController?.delegate = self
        self.host = host
        top.present(host, animated: true)
        // UIKit refuses some presentations (the target is already presenting,
        // mid-transition, or not in a window) with only a console warning.
        // Check on the next turn of the run loop that the sheet is really up.
        DispatchQueue.main.async { [weak self, weak host] in
            guard let self, self.completion != nil else { return }
            guard let host, host.presentingViewController != nil || host.isBeingPresented else {
                self.finish(false)
                return
            }
        }
    }

    private func close(agreed: Bool) {
        chosenAnswer = agreed
        guard let host else {
            finish(agreed)
            return
        }
        host.dismiss(animated: true) { [weak self] in
            self?.finish(agreed)
        }
    }

    nonisolated func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        MainActor.assumeIsolated { finish(false) }
    }

    private func sheetIsGone() {
        finish(chosenAnswer ?? false)
    }

    /// Idempotent: only the first call reaches `completion`.
    private func finish(_ agreed: Bool) {
        guard let completion else { return }
        self.completion = nil
        host = nil
        chosenAnswer = nil
        completion(agreed)
    }

    static func keyWindowTopViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// Reports, once, that the consent sheet has left the screen for good: it
/// disappeared and is no longer presented. That covers a dismissal from above,
/// which neither the buttons nor the swipe delegate see.
private final class AIConsentHostingController: UIHostingController<AnyView> {
    var onGone: (@MainActor () -> Void)?
    private var didReportGone = false

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // A sheet presented over this one also triggers viewDidDisappear on some
        // presentation styles; only report when this sheet is no longer presented.
        // Strong capture on purpose: after a dismissal from above nothing else
        // holds this controller, and a weak capture would let it deallocate
        // before it reports, leaving the consent waiters queued.
        DispatchQueue.main.async { [self] in
            guard presentingViewController == nil else { return }
            reportGone()
        }
    }

    private func reportGone() {
        guard !didReportGone else { return }
        didReportGone = true
        onGone?()
    }

}
