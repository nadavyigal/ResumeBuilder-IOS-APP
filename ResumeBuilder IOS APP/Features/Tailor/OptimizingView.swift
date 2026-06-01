import SwiftUI

struct OptimizingView: View {
    let mode: ResumeOptimizationLoadingView.Mode

    init(mode: ResumeOptimizationLoadingView.Mode = .optimization) {
        self.mode = mode
    }

    var body: some View {
        ResumeOptimizationLoadingView(mode: mode)
    }
}
