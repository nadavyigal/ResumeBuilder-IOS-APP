import SwiftUI

/// Horizontally scrolled quick-win tiles produced from ATS v2 `/api/ats/score` (`quick_wins`) and quick-flagged suggestions.
struct QuickWinsSection: View {
    let analysis: ResumeAnalysis

    private var cards: [QuickWinCardDisplay] {
        var items: [QuickWinCardDisplay] = []

        for (index, win) in analysis.authQuickWins.enumerated() {
            items.append(.init(
                id: "auth-\(index)-\(win.id)",
                title: (win.rationale ?? win.originalText)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? "Quick improvement",
                detail: previewDetail(for: win),
                effort: ImpactLevel.from(estimatedImpactOrGain: win.estimatedImpact ?? 5),
                symbolName: "bolt.fill",
                tint: AppColors.accentTeal
            ))
        }

        for (index, suggestion) in analysis.suggestions.filter({ $0.quickWin == true }).enumerated() {
            let label = suggestion.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Suggestion"
            items.append(.init(
                id: "suggestion-\(index)-\(suggestion.id)",
                title: label,
                detail: suggestion.category.map { ucfirst($0) },
                effort: ImpactLevel.from(estimatedImpactOrGain: suggestion.estimatedGain ?? 4),
                symbolName: "sparkles",
                tint: AppColors.accentSky
            ))
        }

        return items.prefix(12).map { $0 }
    }

    var body: some View {
        if cards.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Quick wins")
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(cards) { card in
                            QuickWinTile(card: card)
                        }
                    }
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.trailing, AppSpacing.lg)
                }
                .scrollClipDisabled()
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func previewDetail(for win: ATSAuthQuickWinSuggestion) -> String? {
        if let snippet = win.optimizedText?.trimmingCharacters(in: .whitespacesAndNewlines), !snippet.isEmpty {
            let short = snippet.prefix(90)
            return short.count < snippet.count ? String(short) + "…" : String(short)
        }
        return nil
    }

    private func ucfirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}

private struct QuickWinCardDisplay: Identifiable {
    let id: String
    let title: String
    let detail: String?
    let effort: ImpactLevel
    let symbolName: String
    let tint: Color
}

private struct QuickWinTile: View {
    let card: QuickWinCardDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Image(systemName: card.symbolName)
                .foregroundStyle(card.tint)

            Text(card.title)
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = card.detail {
                Text(detail)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: AppSpacing.sm) {
                Text("Effort")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                EffortBadge(level: card.effort)
            }
        }
        .padding(AppSpacing.md)
        .frame(width: 246, alignment: .leading)
        .background(AppColors.accentTeal.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.glassStroke, lineWidth: 1)
        )
    }
}

private struct EffortBadge: View {
    let level: ImpactLevel

    var body: some View {
        Text(level.rawValue)
            .font(.appCaption.bold())
            .foregroundStyle(AppColors.backgroundTop)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 3)
            .background(level.severityPillFill, in: Capsule())
            .accessibilityLabel("Estimated effort \(level.rawValue)")
    }
}

extension ImpactLevel {
    fileprivate var severityPillFill: Color {
        switch self {
        case .high: return Color.red.opacity(0.92)
        case .medium: return Color.orange.opacity(0.95)
        case .low: return Color(red: 0.45, green: 0.75, blue: 0.4)
        }
    }

    static func from(estimatedImpactOrGain value: Int) -> ImpactLevel {
        switch value {
        case 10...: return .high
        case 5..<10: return .medium
        default: return .low
        }
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

#Preview {
    QuickWinsSection(
        analysis: ResumeAnalysis(
            overall: 80,
            ats: 84,
            content: 71,
            design: 73,
            missingKeywords: [],
            suggestions: [
                ATSAuthSuggestion(id: "s1", text: "Reorder skills for JD anchors", category: "keywords", quickWin: true, estimatedGain: 6),
            ],
            authQuickWins: [
                ATSAuthQuickWinSuggestion(
                    id: "qw1",
                    originalText: "Built apps.",
                    optimizedText: "Shipped resilient TypeScript/React apps powering 250k WAU.",
                    estimatedImpact: 12,
                    rationale: "Add missing stack cues",
                    improvementType: nil
                ),
            ]
        )
    )
    .background(AppColors.backgroundMid)
}
