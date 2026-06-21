import SwiftUI
import UIKit

// MARK: - Full Resume Rewrite

struct ExpertFullResumeRewriteView: View {
    let sections: [OptimizedResumeSection]
    let applying: Bool
    var onApplySelectedFields: ([String]) -> Void

    @State private var acceptedSectionIds: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("\(acceptedCount) of \(sections.count) sections selected")
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)

            ForEach(sections) { section in
                Button {
                    toggle(section)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Image(systemName: isAccepted(section) ? "checkmark.circle.fill" : "circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isAccepted(section) ? AppColors.accentTeal : AppColors.textTertiary)
                            Text(section.type.displayName)
                                .font(.appCaption.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer(minLength: 0)
                        }
                        Text(section.body)
                            .font(.caption2)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(5)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(AppSpacing.sm)
                    .background(
                        isAccepted(section) ? AppColors.accentTeal.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: AppRadii.sm)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.sm)
                            .stroke(isAccepted(section) ? AppColors.accentTeal.opacity(0.28) : Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            GradientButton(
                title: acceptedCount == sections.count ? "Apply Full Rewrite" : "Apply Selected Sections",
                isLoading: applying
            ) {
                onApplySelectedFields(acceptedCount == sections.count ? [] : selectedFieldNames)
            }
            .disabled(acceptedSectionIds.isEmpty)
        }
        .onAppear {
            if acceptedSectionIds.isEmpty {
                acceptedSectionIds = Set(sections.map(\.id))
            }
        }
    }

    private var acceptedCount: Int {
        sections.filter { isAccepted($0) }.count
    }

    private var selectedFieldNames: [String] {
        sections
            .filter { isAccepted($0) }
            .map { fieldName(for: $0.type) }
    }

    private func isAccepted(_ section: OptimizedResumeSection) -> Bool {
        acceptedSectionIds.contains(section.id)
    }

    private func toggle(_ section: OptimizedResumeSection) {
        if acceptedSectionIds.contains(section.id) {
            acceptedSectionIds.remove(section.id)
        } else {
            acceptedSectionIds.insert(section.id)
        }
    }

    private func fieldName(for type: ResumeSectionType) -> String {
        switch type {
        case .summary:
            return "summary"
        case .experience:
            return "experience"
        case .skills:
            return "skills"
        case .education:
            return "education"
        case .additional:
            return "certifications"
        }
    }
}

// MARK: - Summary Lab

struct ExpertSummaryOptionsView: View {
    let options: [ExpertSummaryOption]
    let recommendedIndex: Int?
    let selectedIndex: Int?
    let applying: Bool
    var onSelect: (Int) -> Void
    var onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if options.isEmpty {
                Text("No summary options generated.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("Choose a summary to apply:")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                ForEach(options) { option in
                    SummaryOptionRow(
                        option: option,
                        isRecommended: option.id == (recommendedIndex ?? 0),
                        isSelected: option.id == (selectedIndex ?? recommendedIndex ?? 0),
                        onSelect: { onSelect(option.id) }
                    )
                }
            }

            GradientButton(title: "Apply Selected Summary", isLoading: applying, action: onApply)
        }
    }
}

private struct SummaryOptionRow: View {
    let option: ExpertSummaryOption
    let isRecommended: Bool
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AppColors.accentViolet : AppColors.textTertiary)
                    Text(option.style)
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    if isRecommended {
                        Text("Recommended")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.accentSky)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accentSky.opacity(0.12), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
                Text(option.summary)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                if let rationale = option.rationale {
                    Text(rationale)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(AppSpacing.sm)
            .background(
                isSelected ? AppColors.accentViolet.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: AppRadii.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.sm)
                    .stroke(isSelected ? AppColors.accentViolet.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Achievement Quantifier

struct ExpertBulletRewritesView: View {
    let rewrites: [ExpertBulletRewrite]
    let applying: Bool
    var onApply: () -> Void

    @State private var copiedId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if rewrites.isEmpty {
                Text("No bullet rewrites generated. Add concrete metrics in Expert Input and run again.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("\(rewrites.count) bullet\(rewrites.count == 1 ? "" : "s") rewritten")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                ForEach(rewrites) { rewrite in
                    BulletRewriteRow(
                        rewrite: rewrite,
                        isCopied: copiedId == rewrite.id,
                        onCopy: {
                            UIPasteboard.general.string = rewrite.optimizedBullet
                            copiedId = rewrite.id
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                if copiedId == rewrite.id { copiedId = nil }
                            }
                        }
                    )
                }

                let allMissing = rewrites.flatMap { $0.missingMetrics }.filter { !$0.isEmpty }
                if !allMissing.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Add these details for stronger rewrites", systemImage: "exclamationmark.circle")
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(.orange)
                        ForEach(Array(allMissing.prefix(5).enumerated()), id: \.offset) { _, metric in
                            Text("• \(metric)")
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadii.sm))
                }
            }

            GradientButton(title: "Apply Rewrites to Resume", isLoading: applying, action: onApply)
        }
    }
}

private struct BulletRewriteRow: View {
    let rewrite: ExpertBulletRewrite
    let isCopied: Bool
    var onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !rewrite.originalBullet.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("Before:")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .frame(width: 42, alignment: .leading)
                    Text(rewrite.originalBullet)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack(alignment: .top, spacing: 6) {
                Text("After:")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.accentTeal)
                    .frame(width: 42, alignment: .leading)
                Text(rewrite.optimizedBullet)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(isCopied ? AppColors.accentTeal : AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            if !rewrite.evidenceUsed.isEmpty {
                Text("Evidence: \(rewrite.evidenceUsed.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(3)
            }
        }
        .padding(AppSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadii.sm))
    }
}

// MARK: - ATS Deep Report

struct ExpertATSReportView: View {
    let atsReport: ExpertATSReport
    let applying: Bool
    var onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let estimate = atsReport.scoreEstimate {
                HStack {
                    Text("Estimated ATS impact")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("\(scoreLabel(estimate.before)) → \(scoreLabel(estimate.after))")
                        .font(.appSubheadline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            } else if let score = atsReport.score {
                HStack {
                    Text("Match Score")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("\(Int(score.rounded()))%")
                        .font(.appSubheadline.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            if !atsReport.keywordMatches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Keyword coverage")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    ForEach(Array(atsReport.keywordMatches.prefix(8))) { match in
                        KeywordMatchRow(match: match)
                    }
                }
            }

            if !atsReport.recommendedKeywordsToAdd.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Keywords to add to Skills (\(atsReport.recommendedKeywordsToAdd.count))")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    KeywordTagsView(keywords: atsReport.recommendedKeywordsToAdd)
                }
            }

            if !atsReport.keywordPlacements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Placement suggestions")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    ForEach(Array(atsReport.keywordPlacements.prefix(4).enumerated()), id: \.offset) { _, placement in
                        Text("• \(placement)")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            if !atsReport.sectionHeadingCompliance.isEmpty {
                GuidanceListView(title: "Section checks", rows: atsReport.sectionHeadingCompliance)
            }

            if !atsReport.formatGuidance.isEmpty {
                GuidanceListView(title: "Format guidance", rows: atsReport.formatGuidance)
            }

            if !atsReport.acronymCoverage.isEmpty {
                GuidanceListView(title: "Acronym coverage", rows: atsReport.acronymCoverage)
            }

            if atsReport.recommendedKeywordsToAdd.isEmpty && atsReport.keywordPlacements.isEmpty {
                Label("Your resume is well-optimized for this role.", systemImage: "checkmark.seal.fill")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.accentTeal)
            }

            if !atsReport.recommendedKeywordsToAdd.isEmpty {
                GradientButton(title: "Add Keywords to Skills", isLoading: applying, action: onApply)
            }
        }
    }

    private func scoreLabel(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }
}

private struct KeywordMatchRow: View {
    let match: ExpertKeywordMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: match.present == true ? "checkmark.circle.fill" : "plus.circle")
                    .font(.caption)
                    .foregroundStyle(match.present == true ? AppColors.accentTeal : AppColors.accentSky)
                Text(match.keyword)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                if let placement = match.suggestedPlacement {
                    Text(placement)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.accentViolet)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.accentViolet.opacity(0.10), in: Capsule())
                }
            }
            if let note = match.note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(AppSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadii.sm))
    }
}

private struct GuidanceListView: View {
    let title: LocalizedStringKey
    let rows: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
            ForEach(Array(rows.prefix(4).enumerated()), id: \.offset) { _, row in
                Text("• \(row)")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}

private struct KeywordTagsView: View {
    let keywords: [String]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 72, maximum: 160), spacing: 4)],
            alignment: .leading,
            spacing: 4
        ) {
            ForEach(Array(keywords.prefix(20).enumerated()), id: \.offset) { _, kw in
                Text(kw)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.accentViolet)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accentViolet.opacity(0.10), in: Capsule())
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Cover Letter

struct ExpertCoverLetterView: View {
    let variants: [ExpertCoverLetterVariant]
    let selectedIndex: Int?
    let applying: Bool
    var onSelect: (Int) -> Void
    var onApply: () -> Void

    @State private var copiedId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if variants.isEmpty {
                Text("No cover letter variants generated.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("Choose a variant to save:")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                ForEach(variants) { variant in
                    CoverLetterVariantRow(
                        variant: variant,
                        isSelected: variant.id == (selectedIndex ?? 0),
                        isCopied: copiedId == variant.id,
                        onSelect: { onSelect(variant.id) },
                        onCopy: {
                            UIPasteboard.general.string = variant.body
                            copiedId = variant.id
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                if copiedId == variant.id { copiedId = nil }
                            }
                        }
                    )
                }
            }

            Label("Saving does not change your resume text.", systemImage: "info.circle")
                .font(.caption2)
                .foregroundStyle(AppColors.textTertiary)

            GradientButton(title: "Save Cover Letter", isLoading: applying, action: onApply)
        }
    }
}

private struct CoverLetterVariantRow: View {
    let variant: ExpertCoverLetterVariant
    let isSelected: Bool
    let isCopied: Bool
    var onSelect: () -> Void
    var onCopy: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AppColors.accentViolet : AppColors.textTertiary)
                    Text(variant.title ?? variant.tone)
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 0)
                    Button(action: onCopy) {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            Text(isCopied ? "Copied" : "Copy")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isCopied ? AppColors.accentTeal : AppColors.accentSky)
                    }
                    .buttonStyle(.plain)
                }
                if let opening = variant.openingParagraph {
                    Text(opening)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Text(variant.body)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                if let rationale = variant.rationale {
                    Text(rationale)
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(AppSpacing.sm)
            .background(
                isSelected ? AppColors.accentViolet.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: AppRadii.sm)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadii.sm)
                    .stroke(isSelected ? AppColors.accentViolet.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screening Answers

struct ExpertScreeningAnswersView: View {
    let answers: [ExpertScreeningAnswer]
    let applying: Bool
    var onApply: () -> Void

    @State private var copiedId: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if answers.isEmpty {
                Text("No screening answers generated.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("\(answers.count) answer\(answers.count == 1 ? "" : "s") generated")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                ForEach(answers) { answer in
                    ScreeningAnswerRow(
                        answer: answer,
                        isCopied: copiedId == answer.id,
                        onCopy: {
                            UIPasteboard.general.string = answer.answer
                            copiedId = answer.id
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                if copiedId == answer.id { copiedId = nil }
                            }
                        }
                    )
                }
            }

            Label("Saving does not change your resume text.", systemImage: "info.circle")
                .font(.caption2)
                .foregroundStyle(AppColors.textTertiary)

            GradientButton(title: "Save Answers", isLoading: applying, action: onApply)
        }
    }
}

private struct ScreeningAnswerRow: View {
    let answer: ExpertScreeningAnswer
    let isCopied: Bool
    var onCopy: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !answer.question.isEmpty {
                Text(answer.question)
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            HStack(alignment: .top) {
                Text(answer.answer)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(isExpanded ? nil : 4)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(isCopied ? AppColors.accentTeal : AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            if answer.answer.count > 150 {
                Button(isExpanded ? "Show less" : "Show more") {
                    isExpanded.toggle()
                }
                .font(.caption2)
                .foregroundStyle(AppColors.accentSky)
                .buttonStyle(.plain)
            }
            if !answer.evidenceUsed.isEmpty {
                Text("Evidence: \(answer.evidenceUsed.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(3)
            }
            if let confidence = answer.confidenceNote {
                Text(confidence)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(AppSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadii.sm))
    }
}
