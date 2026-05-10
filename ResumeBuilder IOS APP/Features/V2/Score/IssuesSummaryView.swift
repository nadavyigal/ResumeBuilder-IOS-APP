import SwiftUI

private enum IssueImpact: Comparable {
    case high
    case medium
    case low

    static func < (lhs: IssueImpact, rhs: IssueImpact) -> Bool {
        lhs.priority < rhs.priority
    }

    private var priority: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    var label: String {
        switch self {
        case .high: return "High impact"
        case .medium: return "Moderate"
        case .low: return "Polish"
        }
    }

    static func from(suggestion: ATSAuthSuggestion) -> IssueImpact {
        let estimate = suggestion.estimatedGain ?? 0
        if estimate >= 8 { return .high }
        if estimate >= 5 { return .medium }
        return .low
    }

    var capsuleColor: Color {
        switch self {
        case .high: return Color.red.opacity(0.93)
        case .medium: return Color.orange.opacity(0.95)
        case .low: return Color.yellow.opacity(0.9)
        }
    }
}

/// Groups ATS issue-style suggestions (`/api/ats/score` → `suggestions`) by coarse category buckets.
struct IssuesSummaryView: View {
    let analysis: ResumeAnalysis

    private enum IssuePanelKind: Hashable {
        case keywords
        case formatting
        case content
    }

    private struct IssuePanel: Identifiable {
        let kind: IssuePanelKind
        var id: IssuePanelKind { kind }
        let title: String
        let subtitle: String
        let tint: Color
        let suggestions: [ATSAuthSuggestion]
    }

    /// Non–quick wins only — quick wins ride in `QuickWinsSection`.
    private var filteredSuggestions: [ATSAuthSuggestion] {
        analysis.suggestions.filter { suggestion in suggestion.quickWin != true }
    }

    private var panels: [IssuePanel] {
        guard !filteredSuggestions.isEmpty else { return [] }

        func collect(where matcher: (String) -> Bool) -> [ATSAuthSuggestion] {
            filteredSuggestions.filter { matcher(($0.category ?? "").lowercased()) }
        }

        var result: [IssuePanel] = []

        let keywords = collect { cat in
            cat.contains("keyword") || cat.contains("phrase") || cat.contains("semantic") ||
                cat.contains("skills") || cat.contains("must")
        }
        if !keywords.isEmpty {
            result.append(IssuePanel(
                kind: .keywords,
                title: "Keywords & alignment",
                subtitle: "JD language parity & skill surfacing.",
                tint: Color.red.opacity(0.94),
                suggestions: keywords
            ))
        }

        let format = collect { cat in
            cat.contains("format") || cat.contains("template") || cat.contains("layout") || cat.contains("pars")
        }
        if !format.isEmpty {
            result.append(IssuePanel(
                kind: .formatting,
                title: "Format risk",
                subtitle: "ATS parsing safeguards & readable structure.",
                tint: Color.orange.opacity(0.95),
                suggestions: format
            ))
        }

        let pooled = keywords + format
        let remaining = filteredSuggestions.filter { item in !pooled.contains(where: { $0.id == item.id }) }
        if !remaining.isEmpty {
            result.append(IssuePanel(
                kind: .content,
                title: "Content & structure",
                subtitle: "Story, tone, completeness & leadership signals.",
                tint: Color.yellow.opacity(0.95),
                suggestions: remaining
            ))
        }

        return result
    }

    var body: some View {
        if panels.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text("Main issues")
                    .font(.appHeadline)
                    .foregroundStyle(AppColors.textPrimary)

                ForEach(panels) { panel in
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(panel.title)
                            .font(.appSubheadline.bold())
                            .foregroundStyle(AppColors.textPrimary)
                        Text(panel.subtitle)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)

                        ForEach(panel.suggestions.sorted { IssueImpact.from(suggestion: $0) > IssueImpact.from(suggestion: $1) }) { suggestion in
                            let impact = IssueImpact.from(suggestion: suggestion)
                            IssueSuggestionRow(
                                impact: impact,
                                title: headline(for: suggestion),
                                caption: suggestion.text,
                                accent: panel.tint
                            )
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.accentSky.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppColors.glassStroke, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func headline(for suggestion: ATSAuthSuggestion) -> String {
        if let gain = suggestion.estimatedGain, gain > 0 {
            return "Up to \(gain) pts • \(friendlyCategory(from: suggestion.category))"
        }
        return friendlyCategory(from: suggestion.category)
    }

    private func friendlyCategory(from raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Recommendation" }
        return raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct IssueSuggestionRow: View {
    let impact: IssueImpact
    let title: String
    let caption: String?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                SeverityCapsule(title: impact.label, accent: impact.capsuleColor)

                Text(title)
                    .font(.appCaption.bold())
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
                .blendMode(.plusLighter)
                .overlay(accent.opacity(0.08))
        }
        .padding(.vertical, AppSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(impact.label): \(title). \(caption ?? "")")
    }
}

private struct SeverityCapsule: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accent, in: Capsule(style: .continuous))
    }
}

#Preview {
    ScrollView {
        IssuesSummaryView(
            analysis: ResumeAnalysis(
                overall: 70,
                ats: 72,
                content: 64,
                design: 66,
                missingKeywords: [],
                suggestions: [
                    ATSAuthSuggestion(id: "a", text: "Scatter \"React\" bullets through experience instead of burying under skills.", category: "keywords", quickWin: false, estimatedGain: 11),
                    ATSAuthSuggestion(id: "b", text: "Remove tables from experience section.", category: "formatting", quickWin: false, estimatedGain: 6),
                    ATSAuthSuggestion(id: "c", text: "Tighten summary to one metric-led sentence.", category: "content", quickWin: true, estimatedGain: 9),
                    ATSAuthSuggestion(id: "d", text: "Add leadership scope to earliest role bullets.", category: "structure", quickWin: false, estimatedGain: 3),
                ]
            )
        )
    }
    .background(AppColors.backgroundMid)
}
