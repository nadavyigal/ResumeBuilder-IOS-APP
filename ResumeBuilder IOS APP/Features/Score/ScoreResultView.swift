import SwiftUI

struct ScoreResultView: View {
    let result: ATSScoreResult
    let isAuthenticated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ATS Score")
                    .font(.headline)
                Spacer()
                Text("\(result.score?.overall ?? 0)")
                    .font(.title.bold())
            }

            ATSDial(score: result.score?.overall ?? 0)
                .frame(height: 140)

            if let quickWins = result.quickWins, !quickWins.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Wins")
                        .font(.headline)
                    ForEach(quickWins.prefix(3)) { win in
                        Label(win.title ?? win.action ?? win.keyword ?? "Improve keyword alignment", systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                }
            }

            if let preview = result.preview {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Issues")
                        .font(.headline)
                    ForEach(preview.topIssues.prefix(3)) { issue in
                        Text(issue.message ?? issue.text ?? issue.suggestion ?? "ATS issue found")
                            .font(.subheadline)
                    }
                    if let locked = preview.lockedCount, locked > 0 {
                        Text("\(locked) more recommendations unlock with full optimization.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let remaining = result.checksRemaining {
                Text("\(remaining) free checks remaining this week.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(isAuthenticated ? "Use Tailor to generate the optimized resume." : "Sign in to unlock full resume optimization.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
