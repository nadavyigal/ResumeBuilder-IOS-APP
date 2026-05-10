import SwiftUI
import UIKit

struct ExpertReportView: View {
    let report: ExpertReportDisplayModel
    let executiveSummaryVisible: Bool
    let missingEvidence: [String]
    let needsUserInput: Bool
    var showApplyButton: Bool
    var isApplying: Bool
    var onApply: () -> Void

    @State private var evidenceExpanded = false
    @State private var copiedLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if let impact = report.atsImpact {
                atsImpactStrip(impact)
            }

            Text(report.headline)
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            if executiveSummaryVisible, !report.executiveSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(report.executiveSummary)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if needsUserInput || !missingEvidence.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label("Needs your input", systemImage: "exclamationmark.circle.fill")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(.orange)
                    if !missingEvidence.isEmpty {
                        ForEach(missingEvidence, id: \.self) { line in
                            Text("• \(line)")
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadii.md))
            }

            if !report.priorityActions.isEmpty {
                Text("Priority actions")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                ForEach(Array(report.priorityActions.enumerated()), id: \.offset) { index, action in
                    Button {
                        UIPasteboard.general.string = action
                        copiedLabel = "Copied #\(index + 1)"
                        Task {
                            try? await Task.sleep(for: .seconds(1.2))
                            copiedLabel = nil
                        }
                    } label: {
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Text("\(index + 1).")
                                .font(.appCaption.weight(.semibold))
                                .foregroundStyle(AppColors.accentViolet)
                                .frame(width: 22, alignment: .leading)
                            Text(action)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(AppColors.textTertiary)
                        }
                        .padding(AppSpacing.sm)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadii.sm))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !report.evidenceGaps.isEmpty {
                DisclosureGroup(isExpanded: $evidenceExpanded) {
                    ForEach(report.evidenceGaps, id: \.self) { gap in
                        Text("• \(gap)")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } label: {
                    Text("Evidence gaps (\(report.evidenceGaps.count))")
                        .font(.appCaption.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            if showApplyButton {
                GradientButton(title: "Apply Changes", isLoading: isApplying, action: onApply)
            }

            if let copiedLabel {
                Text(copiedLabel)
                    .font(.caption2)
                    .foregroundStyle(AppColors.accentSky)
            }
        }
        .padding(AppSpacing.md)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func pct(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    private func pts(_ value: Double?) -> String {
        guard let value else { return "—" }
        let rounded = Int(value.rounded())
        if rounded > 0 { return "+\(rounded) pts" }
        return "\(rounded) pts"
    }

    private func atsImpactStrip(_ impact: ExpertAtsImpactEstimate) -> some View {
        HStack(spacing: AppSpacing.md) {
            VStack(spacing: 2) {
                Text(pct(impact.before))
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Before")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Image(systemName: "arrow.right")
                .foregroundStyle(AppColors.accentSky)
            VStack(spacing: 2) {
                Text(pct(impact.after))
                    .font(.appSubheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("After (est.)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            Text(pts(impact.delta))
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12), in: Capsule())
        }
    }
}
