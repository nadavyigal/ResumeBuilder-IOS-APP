import SwiftUI

/// Side-by-side comparison for two applications (parity with web compare).
struct ApplicationCompareView: View {
    @Environment(\.dismiss) private var dismiss

    let left: ApplicationItem
    let right: ApplicationItem

    private var leftKeywords: [String] {
        ApplicationJobExtractionKeywords.topKeywords(from: left.jobExtraction, maxCount: 3)
    }

    private var rightKeywords: [String] {
        ApplicationJobExtractionKeywords.topKeywords(from: right.jobExtraction, maxCount: 3)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    CompareColumn(application: left, keywords: leftKeywords)
                    CompareColumn(application: right, keywords: rightKeywords)
                }
                .padding(AppSpacing.md)
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .screenBackground(showRadialGlow: false)
        }
    }
}

private struct CompareColumn: View {
    let application: ApplicationItem
    let keywords: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(application.jobTitle ?? "—")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(application.companyName ?? "—")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ATSCompareRing(score: application.atsScore)

            Text("Top signals")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                if keywords.isEmpty {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(Array(keywords.enumerated()), id: \.offset) { _, line in
                        Text("• \(line)")
                            .font(.caption)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadii.md))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .glassCard(cornerRadius: AppRadii.lg)
    }
}

private struct ATSCompareRing: View {
    let score: Int?

    private var pct: CGFloat {
        let v = max(0, min(100, score ?? 0))
        return CGFloat(v) / 100
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 7)
                    .frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(
                        AngularGradient(
                            colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76, height: 76)
                Text("\(score ?? 0)%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            Text("ATS")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("ATS score \(score ?? 0) percent")
    }
}
