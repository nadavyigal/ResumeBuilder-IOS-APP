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
    private var waiting: [CheckedContinuation<Bool, Never>] = []

    init(defaults: UserDefaults = .standard, presenter: (any AIConsentPresenting)? = nil) {
        self.defaults = defaults
        self.presenter = presenter ?? UIKitAIConsentPresenter()
    }

    var currentStore: AIConsentStore {
        AIConsentStore(identity: AIConsentStore.identity(forUserId: userIdProvider()), defaults: defaults)
    }

    var hasConsented: Bool { currentStore.hasConsented }

    func ensureConsent(source: String) async -> Bool {
        let store = currentStore
        if store.hasConsented { return true }
        return await withCheckedContinuation { continuation in
            waiting.append(continuation)
            guard waiting.count == 1 else { return }
            AnalyticsService.shared.track(.aiConsentShown(source: source))
            presenter.present { [weak self] agreed in
                guard let self else { return }
                if agreed {
                    store.recordConsent()
                    AnalyticsService.shared.track(.aiConsentAccepted(source: source))
                } else {
                    AnalyticsService.shared.track(.aiConsentDeclined(source: source))
                }
                let resumed = self.waiting
                self.waiting = []
                resumed.forEach { $0.resume(returning: agreed) }
            }
        }
    }

    func clearAll() {
        AIConsentStore.clearAll(defaults: defaults)
    }
}

/// Presents `AIConsentSheet` over whatever is on top (a sheet, a full-screen
/// cover, a pushed screen), which a SwiftUI `.sheet` on one view cannot do.
@MainActor
final class UIKitAIConsentPresenter: NSObject, AIConsentPresenting, UIAdaptivePresentationControllerDelegate {
    private var completion: (@MainActor (Bool) -> Void)?
    private weak var host: UIViewController?

    func present(completion: @escaping @MainActor (Bool) -> Void) {
        guard let top = Self.topViewController() else {
            completion(false)
            return
        }
        self.completion = completion
        let localization = LocalizationManager.shared
        let sheet = AIConsentSheet(
            onAgree: { [weak self] in self?.close(agreed: true) },
            onNotNow: { [weak self] in self?.close(agreed: false) }
        )
        .environment(localization)
        .environment(\.locale, localization.locale)
        let host = UIHostingController(rootView: sheet)
        host.overrideUserInterfaceStyle = .dark
        if let sheetController = host.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
        }
        host.presentationController?.delegate = self
        self.host = host
        top.present(host, animated: true)
    }

    private func close(agreed: Bool) {
        guard let host else { return }
        host.dismiss(animated: true) { [weak self] in
            self?.finish(agreed)
        }
    }

    nonisolated func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        MainActor.assumeIsolated { finish(false) }
    }

    private func finish(_ agreed: Bool) {
        let completion = completion
        self.completion = nil
        host = nil
        completion?(agreed)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
