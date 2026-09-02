import Foundation

extension Double {
    /// Rounds to the nearest `Int` without trapping.
    ///
    /// `Int(_:)` on a `Double` **traps** — it kills the process, it does not
    /// throw — when the value is outside `Int`'s range or is NaN. Every score,
    /// percentage and gain in this app originates as a JSON number from the
    /// backend, so the unlabelled initializer turns a malformed response into a
    /// crash. `Int(exactly:)` returns nil there instead.
    ///
    /// Use this wherever "no usable number" is representable. Where the result
    /// must be non-optional, prefer `displayPercent` (which clamps) or supply an
    /// explicit fallback — never fall back to `Int(_:)`.
    ///
    /// See PR #178 and the follow-up sweep: this line existed at 26 sites.
    /// `nonisolated`: the app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION =
    /// MainActor`, so an unannotated extension member here is main-actor bound
    /// and unusable from `Sendable` services like `ExpertWorkflowService`. This
    /// is pure arithmetic on a value type, so it belongs on no actor.
    nonisolated var safeRoundedInt: Int? { Int(exactly: rounded()) }

    /// Normalises a backend score into a `0...100` percentage for display.
    ///
    /// Two things are folded together deliberately, because every call site
    /// needed both:
    ///
    /// 1. **Scale.** The backend has sent this field as both a `0...1` fraction
    ///    and a `0...100` percentage, so a bare value cannot be trusted. Values
    ///    at or below 1 are scaled by 100.
    /// 2. **Range.** The clamp runs in `Double` space, *before* the conversion.
    ///    Clamping afterwards — `min(100, max(0, Int(x.rounded())))`, which is
    ///    what several call sites did — never protects the only input that needs
    ///    it, because the trap happens inside the `Int(...)` it wraps.
    ///
    /// NaN is absorbed by the same clamp: `max(0, .nan)` is 0, because Swift's
    /// `max` returns its first argument when the comparison is false.
    ///
    /// Note the `0...1` rule means a genuine 1% reads as 100%. That ambiguity is
    /// inherent to the wire format and predates this helper; it is preserved
    /// exactly rather than quietly changed here.
    nonisolated var displayPercent: Int {
        let scaled = self <= 1 ? self * 100 : self
        return min(100, max(0, scaled)).safeRoundedInt ?? 0
    }
}
