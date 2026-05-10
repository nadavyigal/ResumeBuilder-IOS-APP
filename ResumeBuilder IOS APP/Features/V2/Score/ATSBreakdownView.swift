import SwiftUI

/// Full-screen ATS pillar breakdown derived from ATS v2 `subscores`, with a heuristic fallback when only coarse dashboard metrics exist.
struct ATSBreakdownView: View {
    let analysis: ResumeAnalysis
    /// When embedded in a sheet, show an explicit Done control.
    var showsDismissButton = false

    /// Animates gauges on first appearance.
    @State private var didAnimateBars = false
    @Environment(\.dismiss) private var dismiss

    private var snapshot: ATSFourPillarSnapshot { analysis.atsFourPillarSnapshot() }

    var body: some View {
        List {
            Section {
                VStack(spacing: AppSpacing.lg) {
                    ScoreRingView(score: analysis.overall, size: 132)
                        .padding(.vertical, AppSpacing.sm)

                    if analysis.subscores == nil {
                        Text("High-level gauges from your latest optimization summary. Run Improve with a job description connected for granular ATS wiring.")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Subscores") {
                ForEach(snapshot.rows) { row in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: row.iconName)
                                .foregroundStyle(barColor(for: row.displayValue))

                            Text(row.title)
                                .font(.appSubheadline.bold())
                                .foregroundStyle(AppColors.textPrimary)

                            Spacer()

                            HStack(spacing: AppSpacing.xs) {
                                Text("\(row.displayValue)")
                                    .font(.appCaption.weight(.bold))
                                    .foregroundStyle(barColor(for: row.displayValue))
                                if let delta = row.deltaFromOriginal, delta != 0 {
                                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                                        .font(.appCaption.bold())
                                        .foregroundStyle(delta > 0 ? Color.green.opacity(0.9) : Color.orange.opacity(0.95))
                                        .accessibilityLabel("Change from original: \(delta > 0 ? "plus \(delta)" : "\(delta)")")
                                }
                            }
                        }

                        Text(row.subtitle)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)

                        AnimatedLinearGauge(
                            fraction: CGFloat(row.displayValue) / 100.0,
                            didAnimateBars: didAnimateBars
                        )
                        .accessibilityLabel("\(row.title), \(row.displayValue) percent")
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("ATS breakdown")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.82, dampingFraction: 0.76)) {
                didAnimateBars = true
            }
        }
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func barColor(for value: Int) -> Color {
        switch analysis.scoreColorBucket(forPercent: value) {
        case .high:   return Color.green.opacity(0.85)
        case .medium: return Color.yellow.opacity(0.92)
        case .low:    return Color.orange.opacity(0.95)
        }
    }
}

/// Lightweight linear progress used for ATS subscore rows.
private struct AnimatedLinearGauge: View {
    let fraction: CGFloat
    let didAnimateBars: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.accentTeal.opacity(0.08))
                    .frame(height: 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentTeal, AppColors.gradientMid],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: clampedBarWidth(for: geometry.size.width), height: 8)
            }
            .animation(.easeInOut(duration: 0.7), value: didAnimateBars)
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func clampedBarWidth(for containerWidth: CGFloat) -> CGFloat {
        let capped = Swift.min(CGFloat(1), Swift.max(CGFloat(0), fraction))
        let target = capped * containerWidth
        guard didAnimateBars else { return 0 }
        return target
    }
}

#Preview {
    NavigationStack {
        ATSBreakdownView(analysis: ResumeAnalysis.dashboard(overall: 78, keywordScore: 72, content: 74, design: 80))
    }
}
