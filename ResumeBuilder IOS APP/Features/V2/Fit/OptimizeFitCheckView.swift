import SwiftUI

/// The fit check, shown between optimizing and accepting.
///
/// Founder direction 2026-07-26: optimize the resume, show the user the fit
/// check (this is the "before") and the potential for improvement, then let
/// them accept and see the improved match score.
///
/// It sits after the optimize run on purpose. The old pre-optimization gate
/// delivered a discouraging verdict before the product had done anything, and
/// was removed for that reason. Here the user already has a tailored rewrite
/// waiting; this screen tells them what it is worth before they take it.
struct OptimizeFitCheckView: View {
    let fit: OptimizeFitPreview?
    let jobTitle: String?
    var onAccept: () -> Void
    var onEditTargetJob: () -> Void

    private var current: Int? { fit?.currentScore }
    private var potential: Int? { fit?.potentialScore }

    /// Only claim a gain we actually measured and that actually goes up.
    ///
    /// `displayScores` is false when the run did not meaningfully beat the
    /// starting resume. In that case the screen still shows what is missing and
    /// what to do next — it just does not present a number pair that reads as a
    /// promise the run did not keep (WP-45 S2).
    private var showsProgression: Bool {
        guard fit?.displayScores == true, let current, let potential else { return false }
        return potential > current
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                scoreCard
                if let gaps = fit?.topGaps, !gaps.isEmpty {
                    gapsCard(gaps)
                }
                Text("Estimated fit vs this job, not a hiring guarantee.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.lg)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .screenBackground(showRadialGlow: true)
        .safeAreaInset(edge: .bottom) { actions }
        .navigationTitle("Match Check")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("YOUR MATCH", systemImage: "target")
                .font(.appCaption.weight(.bold))
                .foregroundStyle(AppColors.accentTeal)

            Text("Here is how you match this job today")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let jobTitle, !jobTitle.isEmpty {
                Text(jobTitle)
                    .font(.appSubheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .center, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Match Score")
                        .font(.appCaption.weight(.bold))
                        .foregroundStyle(AppColors.textTertiary)
                    Text("Your resume matches about \(current ?? 0)% of this job")
                        .font(.appHeadline)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AppSpacing.sm)
                ScoreRingView(score: current ?? 0, size: 92)
            }

            if showsProgression, let current, let potential {
                // Pinned left-to-right: in Hebrew the surrounding RTL layout
                // mirrors this row, which made the journey read backwards and
                // the score appear to DROP.
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(verbatim: "\(current)%")
                            .font(.appSubheadline.weight(.bold))
                            .foregroundStyle(AppColors.textSecondary)
                        Image(systemName: "arrow.right")
                            .font(.appCaption.weight(.bold))
                            .foregroundStyle(AppColors.accentTeal)
                        Text(verbatim: "\(potential)%")
                            .font(.appSubheadline.weight(.bold))
                            .foregroundStyle(AppColors.accentTeal)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityElement(children: .ignore)

                    Text("if you accept the tailored rewrite")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Your match goes from \(current) percent to \(potential) percent if you accept the tailored rewrite"))
            } else {
                // Honest fallback: the rewrite is still worth reviewing, but we
                // do not put a number on it we cannot stand behind.
                Text("We prepared targeted improvements for this job. Review them and see what changes.")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private func gapsCard(_ gaps: [OptimizeFitGap]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("What is holding it back", systemImage: "exclamationmark.triangle.fill")
                .font(.appCaption.weight(.bold))
                .foregroundStyle(AppColors.accentSky)

            ForEach(Array(gaps.prefix(3).enumerated()), id: \.offset) { _, gap in
                if let title = gap.title, !title.isEmpty {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Circle()
                            .fill(AppColors.accentSky)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(title)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .glassCard(cornerRadius: AppRadii.lg)
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            GradientButton(title: "Accept optimization", icon: "sparkles") {
                onAccept()
            }
            Button("Edit target job") { onEditTargetJob() }
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(AppSpacing.lg)
        .background(.ultraThinMaterial.opacity(0.9))
    }
}
