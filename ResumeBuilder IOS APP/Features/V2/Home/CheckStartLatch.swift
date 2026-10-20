import Foundation

/// Lets one "Check my fit" start through at a time, from the tap until the check
/// task exists or the user declines consent.
///
/// Without it, two quick taps before the consent sheet appears each wait on the
/// same sheet, both resume on "Agree", and two optimizer requests go out while
/// `checkTask` keeps only the second, so Cancel cannot stop the first (PR #200
/// review).
struct CheckStartLatch: Equatable {
    private(set) var isStarting = false

    /// True if this caller may start; false while another start is in flight.
    mutating func begin() -> Bool {
        guard !isStarting else { return false }
        isStarting = true
        return true
    }

    mutating func end() {
        isStarting = false
    }
}
