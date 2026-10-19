import SwiftUI

/// The four steps Home's check shows, in order. Each one advances once and the
/// last one holds until the check ends, so the screen never loops back. The old
/// inline loader cycled its status line on a 1.7 second timer forever.
enum HomeCheckStage: Int, CaseIterable, Comparable {
    case readingResume
    case readingJob
    case comparing
    case preparingDiagnosis

    var title: LocalizedStringKey {
        switch self {
        case .readingResume: return "Reading your résumé"
        case .readingJob: return "Reading the job"
        case .comparing: return "Comparing requirements and experience"
        case .preparingDiagnosis: return "Preparing the diagnosis"
        }
    }

    static func < (lhs: HomeCheckStage, rhs: HomeCheckStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Shortest time the upload-tied first stage stays up, so a résumé that was
    /// already uploaded for this job does not flash past.
    static let minimumResumeRead: TimeInterval = 1.2
    /// First stage length on a path with no separate upload (the free check, an apply).
    static let timedResumeRead: TimeInterval = 2.5
    static let readingJobDuration: TimeInterval = 4
    static let comparingDuration: TimeInterval = 8

    /// The stage for a check that started `elapsed` seconds ago.
    ///
    /// - Parameters:
    ///   - resumeReadAt: seconds after the start when the upload finished; nil while it runs.
    ///   - tracksUpload: false on a path with no separate upload; the first stage then ends on time.
    static func at(elapsed: TimeInterval, resumeReadAt: TimeInterval?, tracksUpload: Bool) -> HomeCheckStage {
        let resumeReadEnd: TimeInterval
        if tracksUpload {
            guard let resumeReadAt else { return .readingResume }
            resumeReadEnd = max(resumeReadAt, minimumResumeRead)
        } else {
            resumeReadEnd = timedResumeRead
        }
        let afterResume = elapsed - resumeReadEnd
        if afterResume < 0 { return .readingResume }
        if afterResume < readingJobDuration { return .readingJob }
        if afterResume < readingJobDuration + comparingDuration { return .comparing }
        return .preparingDiagnosis
    }
}

/// How the check screen names the job: the link's site, or "Pasted description".
enum HomeCheckJobLabel: Equatable {
    case site(String)
    case pastedDescription

    static func from(normalizedURL: String?) -> HomeCheckJobLabel {
        guard let normalizedURL,
              let host = URL(string: normalizedURL)?.host(),
              !host.isEmpty else { return .pastedDescription }
        return .site(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
    }
}

/// Home's check, full screen (Story B of the Home redesign). Presented with
/// `fullScreenCover`, so the tab bar is hidden and nothing behind it can be edited.
struct HomeCheckScreen: View {
    /// Whether this check has a separate upload the first stage can wait on.
    enum Upload: Equatable {
        /// The free check and an apply send no separate upload; the first stage ends on time.
        case untracked
        case inProgress
        case finished
    }

    let resumeName: String
    let job: HomeCheckJobLabel
    let upload: Upload
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()
    @State private var resumeReadAt: TimeInterval?
    /// The furthest stage shown. Only ever moves forward.
    @State private var reached: HomeCheckStage = .readingResume

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            VStack(spacing: AppSpacing.sm) {
                Text("Checking your fit")
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Comparing your résumé with the job requirements.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            documentPair

            stageList

            Spacer(minLength: 0)

            Button(action: onCancel) {
                Text("Cancel check")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusButton, style: .continuous)
                            .strokeBorder(AppColors.glassStroke, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, AppSpacing.xxxl)
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .resumelyBackground(glow: AppColors.accentSky)
        .onAppear {
            if upload == .finished { resumeReadAt = 0 }
        }
        .onChange(of: upload) { _, newValue in
            if newValue != .inProgress, resumeReadAt == nil {
                resumeReadAt = Date().timeIntervalSince(startedAt)
            }
            refreshStage()
        }
        .task {
            while !Task.isCancelled {
                refreshStage()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func refreshStage() {
        let stage = HomeCheckStage.at(
            elapsed: Date().timeIntervalSince(startedAt),
            resumeReadAt: resumeReadAt,
            tracksUpload: upload != .untracked || resumeReadAt != nil
        )
        guard stage > reached else { return }
        if reduceMotion {
            reached = stage
        } else {
            withAnimation(.easeOut(duration: 0.3)) { reached = stage }
        }
    }

    // MARK: - Résumé and job

    private var documentPair: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            documentColumn(
                caption: "Résumé",
                isReading: reached == .readingResume || reached >= .comparing,
                tint: AppColors.accentCyan,
                page: Color.white.opacity(0.94)
            ) {
                Text(verbatim: resumeName)
            }

            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.accentSky)
                .frame(width: 36, height: 36)
                .background(AppColors.accentSky.opacity(0.14), in: Circle())
                .padding(.top, 40)
                .accessibilityHidden(true)

            documentColumn(
                caption: "Job",
                isReading: reached >= .readingJob,
                tint: AppColors.gradientMid,
                page: Color(hex: "EAF2FD")
            ) {
                switch job {
                case .site(let host): Text(verbatim: host)
                case .pastedDescription: Text("Pasted description")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func documentColumn<Name: View>(
        caption: LocalizedStringKey,
        isReading: Bool,
        tint: Color,
        page: Color,
        @ViewBuilder name: () -> Name
    ) -> some View {
        VStack(spacing: AppSpacing.sm) {
            miniPage(isReading: isReading, tint: tint, page: page)
                .accessibilityHidden(true)

            VStack(spacing: 2) {
                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textTertiary)
                name()
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
    }

    private func miniPage(isReading: Bool, tint: Color, page: Color) -> some View {
        let widths: [CGFloat] = [0.55, 0.85, 0.7, 0.9, 0.65, 0.8]
        return VStack(alignment: .leading, spacing: 7) {
            ForEach(widths.indices, id: \.self) { index in
                Capsule()
                    .fill(isReading && index.isMultiple(of: 2) ? tint.opacity(0.7) : Color.black.opacity(0.16))
                    .frame(width: 72 * widths[index], height: 5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .frame(width: 92, height: 116, alignment: .topLeading)
        .background(page, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            // Driven by the clock, not a repeating animation: the beam comes and
            // goes with the stage, and a repeat started before it was inserted
            // left it frozen at the bottom of the page.
            if isReading && !reduceMotion {
                TimelineView(.animation) { context in
                    let cycle = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 2.4) / 2.4
                    LinearGradient(
                        colors: [tint.opacity(0), tint.opacity(0.45), tint.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 18)
                    .offset(y: -52 + 104 * cycle)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isReading)
    }

    // MARK: - Stages

    private var stageList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(HomeCheckStage.allCases, id: \.self) { stage in
                stageRow(stage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
    }

    private func stageRow(_ stage: HomeCheckStage) -> some View {
        let isDone = stage < reached
        let isCurrent = stage == reached
        return HStack(spacing: AppSpacing.md) {
            ZStack {
                if isDone {
                    Circle().fill(AppGradients.primary)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                } else if isCurrent {
                    Circle()
                        .strokeBorder(AppColors.accentCyan, lineWidth: 2)
                        .background(Circle().fill(AppColors.accentCyan.opacity(0.15)).padding(-4))
                    if !reduceMotion {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(AppColors.accentCyan)
                    }
                } else {
                    Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5)
                }
            }
            .frame(width: 24, height: 24)

            Text(stage.title)
                .font(.body.weight(isCurrent ? .bold : .regular))
                .foregroundStyle(isCurrent ? Theme.textPrimary : (isDone ? Theme.textSecondary : Theme.textTertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(stage.title))
        .accessibilityValue(Text(isDone ? "Finished" : (isCurrent ? "In progress" : "Not started yet")))
    }
}

#Preview {
    HomeCheckScreen(
        resumeName: "Nadav Yigal CV 2024 - new version.pdf",
        job: .site("linkedin.com"),
        upload: .inProgress,
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
