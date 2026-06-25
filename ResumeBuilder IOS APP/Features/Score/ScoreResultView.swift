import SwiftUI

struct ScoreResultView: View {
    let result: ATSScoreResult
    let isAuthenticated: Bool

    var body: some View {
        let score = result.score?.overall ?? 0

        VStack(alignment: .leading, spacing: 20) {
            Text("YOUR FIRST DIAGNOSIS")
                .font(.caption.weight(.black))
                .kerning(1.1)
                .foregroundStyle(AppColors.accentSky)

            HStack(alignment: .center, spacing: AppSpacing.xl) {
                ATSDial(score: score)
                    .frame(width: 138, height: 138)
                    .overlay {
                        VStack(spacing: 0) {
                            Text("\(score)")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                            Text("out of 100")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.textTertiary)
                        }
                    }

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(verdict(for: score))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Based on formatting + keyword match vs the job you paste. Not affiliated with any ATS vendor.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            statRow

            // ── Quick wins ────────────────────────────────────────────────────
            if let quickWins = result.quickWins, !quickWins.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Biggest win", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accentCyan)

                    if let win = quickWins.first {
                        Text(win.title ?? win.action ?? win.keyword ?? NSLocalizedString("Improve keyword alignment", comment: ""))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if quickWins.count > 1 {
                        Text(String(format: NSLocalizedString("See all %lld fixes to keep climbing.", comment: ""), quickWins.count))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(16)
                .background(AppColors.accentViolet.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                        .strokeBorder(AppColors.accentViolet.opacity(0.22), lineWidth: 1)
                )
            }

            // ── Top issues ────────────────────────────────────────────────────
            if let preview = result.preview {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Top Issues", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)

                    ForEach(preview.topIssues.prefix(3)) { issue in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Theme.accent)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(issue.message ?? issue.text ?? issue.suggestion ?? NSLocalizedString("ATS issue found", comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    if let locked = preview.lockedCount, locked > 0 {
                        Text("\(locked) more recommendations unlock with full optimization.")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 2)
                    }
                }
                .padding(14)
                .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radiusBadge, style: .continuous))
            }

            // ── Footer ────────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                if let remaining = result.checksRemaining {
                    Text("\(remaining) free checks remaining this week.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                Text(isAuthenticated
                     ? "Use Tailor to generate the full optimized resume."
                     : "Sign in to unlock full resume optimization.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(18)
        .background(Theme.bgCard, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                .stroke(Theme.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private func verdict(for score: Int) -> String {
        switch score {
        case ..<50:
            return NSLocalizedString("Let's fix the basics", comment: "")
        case 50..<75:
            return NSLocalizedString("Good start — a few quick fixes can help", comment: "")
        default:
            return NSLocalizedString("Strong — polish it", comment: "")
        }
    }

    /// Real data only — the backend doesn't return a per-category (keywords/format/impact)
    /// breakdown yet, so this shows actual counts instead of faking distinct sub-scores.
    @ViewBuilder
    private var statRow: some View {
        let tiles = statTiles
        if !tiles.isEmpty {
            HStack(spacing: AppSpacing.sm) {
                ForEach(tiles, id: \.id) { tile in
                    diagnosisTile(tile.title, value: tile.value)
                }
            }
        }
    }

    private var statTiles: [(id: String, title: LocalizedStringKey, value: String)] {
        var tiles: [(id: String, title: LocalizedStringKey, value: String)] = []
        if let totalIssues = result.preview?.totalIssues {
            tiles.append(("issues_found", "Issues found", "\(totalIssues)"))
        }
        if let quickWins = result.quickWins, !quickWins.isEmpty {
            tiles.append(("quick_wins", "Quick wins", "\(quickWins.count)"))
        }
        if let remaining = result.checksRemaining {
            tiles.append(("checks_left", "Checks left", "\(remaining)"))
        }
        return tiles
    }

    private func diagnosisTile(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.glassTint, in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                .strokeBorder(AppColors.glassStroke, lineWidth: 1)
        )
    }
}
