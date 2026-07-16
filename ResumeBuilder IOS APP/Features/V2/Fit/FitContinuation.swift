import Foundation

/// Decides what the Fit surface shows when the journey continues into it.
///
/// Fit used to open on its own entry form: the same job the user had just typed
/// on Home, re-presented with a "Check Fit" button. That form asked the user to
/// confirm work they had already done. When a usable job is carried in, Fit runs
/// on it directly — the target stays editable, so nothing is taken away.
nonisolated struct FitContinuation: Sendable {

    enum Step: Equatable, Sendable {
        /// A usable job was carried in — run Fit on it, no confirmation form.
        case runAutomatically
        /// Nothing usable was carried — the job genuinely has to be asked for.
        case askForJob
        /// The user chose to change the target before optimizing.
        case editTarget
        /// A verdict exists.
        case showVerdict
        /// Fit failed. Shown in place, so a failure never reappears as the
        /// confirmation form this story removes.
        case showFailure
    }

    /// Editing wins over everything: the user must always be able to change the
    /// target job, whatever else is on screen.
    static func step(
        carriedJobIsReady: Bool,
        hasVerdict: Bool,
        hasFailed: Bool,
        isEditingTarget: Bool
    ) -> Step {
        if isEditingTarget { return .editTarget }
        if hasVerdict { return .showVerdict }
        if hasFailed { return .showFailure }
        return carriedJobIsReady ? .runAutomatically : .askForJob
    }
}
