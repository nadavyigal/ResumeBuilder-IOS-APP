import CryptoKit
import Foundation

/// The last "Check my fit" that finished, and what it ran on. Pressing the
/// check again on the same file, job and account reuses it instead of a new AI
/// run (tester, 2026-11-12: three identical checks, three full runs; a guest's
/// checks also count against the server's free limit, and accepting each new
/// review mints and bills another optimization).
///
/// `TailorViewModel` owns one and asks it before every check.
@MainActor
struct RepeatCheckCache {
    struct CompletedCheck {
        let inputKey: String
        let identity: String
        let reviewId: String?
        let fitPreview: OptimizeFitPreview?
        /// The optimization this check became: the direct flow's id, or the
        /// one minted when the user accepted the review.
        var optimizationId: String?
    }

    private(set) var lastCheck: CompletedCheck?

    /// The finished check for these inputs and this account, if any.
    func match(inputKey: String?, identity: String) -> CompletedCheck? {
        guard let inputKey, let last = lastCheck,
              last.inputKey == inputKey, last.identity == identity else { return nil }
        return last
    }

    /// Records a check that returned a review or an optimization. A run without
    /// an input key (unreadable file) is never recorded, so it never reuses.
    mutating func record(inputKey: String?, identity: String, reviewId: String?, optimizationId: String?, fitPreview: OptimizeFitPreview?) {
        guard let inputKey, reviewId != nil || optimizationId != nil else { return }
        lastCheck = CompletedCheck(
            inputKey: inputKey,
            identity: identity,
            reviewId: reviewId,
            fitPreview: fitPreview,
            optimizationId: optimizationId
        )
    }

    /// The optimization the user's accept minted for `reviewId`.
    mutating func recordAccepted(reviewId: String?, optimizationId: String) {
        guard let reviewId, lastCheck?.reviewId == reviewId else { return }
        lastCheck?.optimizationId = optimizationId
    }

    mutating func reset() {
        lastCheck = nil
    }

    /// What a check depends on: the file's bytes (a different file under the
    /// same name is a different check) and the job as sent. Nil when the file
    /// cannot be read. Reads the whole file, so call it off the main thread.
    nonisolated static func inputKey(fileURL: URL, jobInput: JobInputPolicy.Evaluation) -> String? {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return nil }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return [digest, jobInput.normalizedDescription ?? "", jobInput.normalizedURL ?? ""]
            .joined(separator: "\u{1F}")
    }
}
