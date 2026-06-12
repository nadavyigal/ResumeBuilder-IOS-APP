import SwiftUI

@MainActor
struct ResumeOptimizationLoadingView: View {
    enum Mode: Sendable {
        case optimization
        case atsCheck
        case diagnosis

        var title: String {
            switch self {
            case .optimization:
                return "Optimizing your resume"
            case .atsCheck:
                return "Scanning your resume"
            case .diagnosis:
                return "Preparing your diagnosis"
            }
        }

        var subtitle: String {
            switch self {
            case .optimization:
                return "Matching your experience to this role."
            case .atsCheck:
                return "Checking ATS signals before you sign in."
            case .diagnosis:
                return "Turning resume and job signals into recruiter-style feedback."
            }
        }

        var statusMessages: [String] {
            switch self {
            case .optimization:
                return [
                    "Reading your resume",
                    "Comparing against the job",
                    "Finding missing signals",
                    "Preparing recruiter-style feedback"
                ]
            case .atsCheck:
                return [
                    "Reading the resume",
                    "Finding ATS signals",
                    "Checking keywords",
                    "Preparing your score"
                ]
            case .diagnosis:
                return [
                    "Reading your resume",
                    "Comparing against the job",
                    "Finding missing signals",
                    "Preparing recruiter-style feedback"
                ]
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let mode: Mode

    init(mode: Mode = .optimization) {
        self.mode = mode
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.8 : 1.0 / 30.0)) { context in
            let timestamp = context.date.timeIntervalSinceReferenceDate
            let progress = reduceMotion ? 0.5 : scanProgress(timestamp)
            let captionIndex = reduceMotion ? 0 : Int(timestamp / 1.7) % mode.statusMessages.count
            let pulse = 0.92 + (sin(timestamp * 2.4) + 1) * 0.04

            VStack(spacing: AppSpacing.lg) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    resumeScanScene(progress: progress, pulse: pulse)
                        .frame(width: 132, height: 164)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.accentSky)
                            Text(mode.title)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(mode.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        statusPill(mode.statusMessages[captionIndex], pulse: pulse)
                            .padding(.top, AppSpacing.xs)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, AppSpacing.sm)
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: AppRadii.lg)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(mode.title). \(mode.subtitle) \(mode.statusMessages[captionIndex]).")
        }
    }

    private func scanProgress(_ timestamp: TimeInterval) -> Double {
        let cycle = timestamp.truncatingRemainder(dividingBy: 3.2) / 3.2
        return cycle < 0.82 ? cycle / 0.82 : 1.0
    }

    private func resumeScanScene(progress: Double, pulse: Double) -> some View {
        let xOffset = -36 + (72 * progress)
        let yOffset = -48 + (92 * progress)

        return ZStack {
            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                .fill(Theme.bgPrimary.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                        .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                )

            resumePage(progress: progress)
                .padding(AppSpacing.md)

            if !reduceMotion {
                scanBeam(progress: progress)
                    .offset(x: xOffset, y: yOffset)
                    .opacity(progress < 0.96 ? 1 : 0)
            }

            magnifier
                .offset(x: reduceMotion ? 14 : xOffset, y: reduceMotion ? -10 : yOffset)
                .scaleEffect(reduceMotion ? pulse : 1)
        }
    }

    private func resumePage(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(AppColors.accentSky.opacity(0.34))
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 4) {
                    line(width: 48, height: 5, opacity: 0.46, isHighlighted: progress < 0.2)
                    line(width: 72, height: 4, opacity: 0.2, isHighlighted: false)
                }
            }

            Divider()
                .background(Color.white.opacity(0.1))

            ForEach(0..<6, id: \.self) { index in
                line(
                    width: lineWidth(for: index),
                    height: 5,
                    opacity: index.isMultiple(of: 2) ? 0.25 : 0.17,
                    isHighlighted: highlightedLine(for: index, progress: progress)
                )
            }

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                keywordChip(width: 30, progress: progress, threshold: 0.68)
                keywordChip(width: 38, progress: progress, threshold: 0.78)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
        .shadow(color: AppColors.accentSky.opacity(0.16), radius: 18, y: 8)
    }

    private func line(width: CGFloat, height: CGFloat, opacity: Double, isHighlighted: Bool) -> some View {
        Capsule()
            .fill(isHighlighted ? AppColors.accentCyan.opacity(0.55) : Color.black.opacity(opacity))
            .frame(width: width, height: height)
            .animation(.easeInOut(duration: 0.28), value: isHighlighted)
    }

    private func keywordChip(width: CGFloat, progress: Double, threshold: Double) -> some View {
        Capsule()
            .fill(progress > threshold ? AppColors.accentSky.opacity(0.26) : Color.black.opacity(0.08))
            .frame(width: width, height: 10)
            .animation(.easeInOut(duration: 0.25), value: progress > threshold)
    }

    private func scanBeam(progress: Double) -> some View {
        RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AppColors.accentCyan.opacity(0),
                        AppColors.accentCyan.opacity(0.32),
                        AppColors.accentSky.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 86, height: 34)
            .rotationEffect(.degrees(-18))
            .blur(radius: 0.5)
            .animation(.easeInOut(duration: 0.18), value: progress)
    }

    private var magnifier: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 52, height: 52)
                .overlay(
                    Circle()
                        .strokeBorder(AppGradients.heroRing, lineWidth: 3)
                )
                .shadow(color: AppColors.accentSky.opacity(0.32), radius: 16, y: 8)

            Circle()
                .fill(AppColors.accentSky.opacity(0.12))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                )

            Capsule()
                .fill(AppColors.accentSky)
                .frame(width: 25, height: 5)
                .rotationEffect(.degrees(45))
                .offset(x: 25, y: 25)
        }
    }

    private func statusPill(_ text: String, pulse: Double) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Circle()
                .fill(AppColors.accentCyan)
                .frame(width: 7, height: 7)
                .scaleEffect(pulse)

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.accentSky.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(AppColors.accentSky.opacity(0.24), lineWidth: 1)
        )
    }

    private func lineWidth(for index: Int) -> CGFloat {
        [72, 88, 58, 82, 66, 92][index]
    }

    private func highlightedLine(for index: Int, progress: Double) -> Bool {
        let lower = 0.2 + (Double(index) * 0.1)
        let upper = lower + 0.16
        return progress >= lower && progress <= upper
    }
}

#Preview {
    VStack(spacing: AppSpacing.lg) {
        ResumeOptimizationLoadingView(mode: .optimization)
        ResumeOptimizationLoadingView(mode: .atsCheck)
    }
    .padding()
    .resumelyBackground(glow: AppColors.accentSky)
    .preferredColorScheme(.dark)
}
