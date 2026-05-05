import SwiftUI

// Thin backward-compatibility wrapper. New code should use ScoreRingView directly.
struct ATSDial: View {
    let score: Int

    var body: some View {
        ScoreRingView(score: score, size: 140)
    }
}
