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
///
/// The layout deliberately follows `FitVerdictView`, the screen this replaced
/// (founder, device test 2026-07-27: "same content, but the UI should be what
/// it was a week ago"). That means a band header, one large centred score ring
/// and stacked sections — not the compact side-by-side card this briefly used.
struct OptimizeFitCheckView: View {
    let fit: OptimizeFitPreview?
    let jobTitle: String?
    var onAccept: () -> Void
    var onEditTargetJob: () -> Void
    /// Drives the accept button's spinner and disables both actions while the
    /// apply is in flight. Defaults to false so existing call sites compile, but
    /// any caller that does real work in `onAccept` must pass it.
    var isApplying: Bool = false

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
            VStack(spacing: AppSpacing.xl) {
                bandHeader
                scoreSection
                if showsProgression { progressionSection }
                if let gaps = fit?.topGaps, !gaps.isEmpty {
                    gapsSection(gaps)
                }
                scoreDisclaimer
                Spacer(minLength: AppSpacing.xxl)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .screenBackground(showRadialGlow: true)
        .safeAreaInset(edge: .bottom) { actions }
        .navigationTitle(NSLocalizedString("Match Check", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Band header

    private var bandHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(bandLabel)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(bandColor)
                .multilineTextAlignment(.center)

            Text(bandDescription)
                .font(.appBody)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let jobTitle, !jobTitle.isEmpty {
                Text(jobTitle)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(bandColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Bands come from `FitVerdict.swift`, which carries the calibrated
    /// thresholds — so this screen and the standalone verdict never disagree
    /// about what a given score is called.
    private var band: FitBand { FitBand.derived(from: current ?? 0) }

    private var bandLabel: String {
        switch band {
        case .strong: return NSLocalizedString("Strong Fit", comment: "")
        case .stretch: return NSLocalizedString("Stretch Fit", comment: "")
        case .skip: return NSLocalizedString("Weak Fit", comment: "")
        }
    }

    private var bandDescription: String {
        switch band {
        case .strong:
            return NSLocalizedString(
                "Your resume signals align well with this role. The tailored rewrite can sharpen it further.",
                comment: ""
            )
        case .stretch:
            return NSLocalizedString(
                "You could compete for this role. The tailored rewrite closes some of the gaps below.",
                comment: ""
            )
        case .skip:
            return NSLocalizedString(
                "Your resume is a weak match for this role today. The tailored rewrite is where to start.",
                comment: ""
            )
        }
    }

    private var bandColor: Color {
        switch band {
        case .strong: return AppColors.accentTeal
        case .stretch: return Color.orange
        case .skip: return Color.red
        }
    }

    // MARK: - Score ring

    private var scoreSection: some View {
        VStack(spacing: AppSpacing.md) {
            ScoreRingView(score: current ?? 0, size: 120)

            Text(NSLocalizedString("Resumely Match Score", comment: ""))
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - What accepting is worth

    private var progressionSection: some View {
        VStack(spacing: AppSpacing.sm) {
            // Pinned left-to-right: in Hebrew the surrounding RTL layout mirrors
            // this row, which made the journey read backwards and the score
            // appear to DROP.
            HStack(spacing: AppSpacing.sm) {
                Text(verbatim: "\(current ?? 0)%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.appSubheadline.weight(.bold))
                    .foregroundStyle(AppColors.accentTeal)
                Text(verbatim: "\(potential ?? 0)%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.accentTeal)
            }
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityElement(children: .ignore)

            Text(NSLocalizedString("if you accept the tailored rewrite", comment: ""))
                .font(.appCaption)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: AppRadii.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("Your match goes from \(current ?? 0) percent to \(potential ?? 0) percent if you accept the tailored rewrite")
        )
    }

    // MARK: - Gaps

    private func gapsSection(_ gaps: [OptimizeFitGap]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader(
                icon: "exclamationmark.triangle.fill",
                title: NSLocalizedString("What is holding it back", comment: ""),
                color: Color.orange
            )

            ForEach(Array(gaps.prefix(3).enumerated()), id: \.offset) { _, gap in
                if let title = gap.title, !title.isEmpty {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)

                        Text(title)
                            .font(.appSubheadline)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.appCaption.weight(.bold))
            .foregroundStyle(color)
    }

    private var scoreDisclaimer: some View {
        Text(NSLocalizedString("Estimated fit vs this job, not a hiring guarantee.", comment: ""))
            .font(.appCaption)
            .foregroundStyle(AppColors.textTertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            // Accepting now runs the apply itself — it used to only push the
            // review screen, which owned its own submitting state and disabled
            // its button. Without a busy state here the screen sat still for the
            // whole round trip and taps stacked up: on device 2026-08-12 three
            // taps produced three applies and three separate optimizations.
            GradientButton(title: "Accept optimization", icon: "sparkles", isLoading: isApplying) {
                guard !isApplying else { return }
                onAccept()
            }
            .disabled(isApplying)

            Button("Edit target job") { onEditTargetJob() }
                .font(.appSubheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(isApplying)
        }
        .padding(AppSpacing.lg)
        .background(.ultraThinMaterial.opacity(0.9))
    }
}
