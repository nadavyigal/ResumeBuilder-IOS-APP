import Foundation

/// Process-wide memory of which "this screen was seen" events have already fired.
///
/// Impression events used to be deduplicated by a `Set` held in `@State` on the
/// view that fires them. That makes the guard as short-lived as the view, and
/// SwiftUI rebuilds views for reasons that have nothing to do with the user
/// seeing something new — a changed `.id`, a swapped view model, a parent
/// re-render.
///
/// Observed on device, 1.4.9 (19), 2026-08-12 10:39:40: `optimized_viewed`,
/// `export_cta_seen` and `saved_resume_prompt_viewed` each fired twice in the
/// same millisecond — once for the optimization the user had just applied, and
/// once for the *previous* one, whose view was still mounted while the tab
/// swapped over. Two live views, two empty `Set`s, two impressions, one of them
/// carrying a stale `optimization_id`.
///
/// Keying the guard to the app process instead of the view gives these events
/// the semantics a funnel actually needs: **first time this optimization was
/// seen**, counted once, no matter how the view tree churns getting there.
@MainActor
final class ImpressionLog {
    static let shared = ImpressionLog()

    private var claimed: Set<String> = []

    init() {}

    /// Claims one impression. Returns `true` exactly once per key.
    ///
    /// Call it as the condition of the `track` — if it returns `false` the
    /// impression has already been recorded and must not be sent again.
    func claim(_ event: String, id: String) -> Bool {
        claimed.insert("\(event):\(id)").inserted
    }

    /// Test seam. Never call from app code — impressions are meant to survive
    /// for the life of the process.
    func resetForTesting() {
        claimed.removeAll()
    }
}
