#if DEBUG
import SwiftUI

/// Renders `ResumeDiagnosisView` with fixture data.
///
/// The diagnosis screen sits behind sign-in and a completed optimization, so it
/// cannot be reached in a simulator without an account. This harness makes the
/// fit journey — the number the user starts at, and where the next step takes
/// them — reviewable on screen, including in Hebrew RTL.
///
/// DEBUG only, reached via `--smoke-diagnosis`, following the same convention as
/// `--smoke-open-optimized-tab`. It ships in no Release build.
struct DiagnosisSmokeHarness: View {
    @State private var appState = AppState()

    /// `--smoke-he` renders the same screen in Hebrew RTL, which is the layout
    /// worth checking: the journey strip mixes Latin digits with Hebrew text
    /// and an arrow whose direction has to follow the language.
    private var wantsHebrew: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-he")
    }

    /// The journey the founder described: 29 at the fit check, 48 after the
    /// tailored rewrite. Gap text deliberately repeats the title in the
    /// explanation for the first item, so the de-duplication is visible here.
    private var fixture: ResumeDiagnosis {
        ResumeDiagnosis(
            matchScore: 29,
            potentialScore: 48,
            scoreNote: "Estimated fit vs this job, not a hiring guarantee.",
            topGaps: [
                // First gap repeats its title in the explanation on purpose, so
                // the de-duplication is visible on screen rather than only in a
                // unit test.
                ResumeGap(
                    title: "Add at least one metric to your most recent role",
                    explanation: "Add at least one metric to your most recent role",
                    severity: .high
                ),
                ResumeGap(
                    title: "No timeframes showing speed of delivery",
                    explanation: "Add a duration to one bullet, for example 'in 3 months'.",
                    severity: .medium
                ),
                ResumeGap(
                    title: "Title wording differs from the job",
                    explanation: "The posting says Business Development Manager.",
                    severity: .medium
                ),
            ],
            missingKeywords: [
                ResumeKeyword(keyword: "partnerships", importance: .high),
                ResumeKeyword(keyword: "pipeline", importance: .medium),
            ],
            recruiterReview: RecruiterReview(
                impression: "A recruiter may see relevant experience, but the resume needs sharper proof for Business Development Manager at XTEND.",
                strengths: ["Relevant industry background", "Clear career progression"],
                concerns: ["No quantified outcomes", "Title wording differs from the posting"],
                nextFix: "Add one measurable result to the most recent role."
            ),
            beforeAfter: [
                BulletRewrite(
                    before: "Responsible for partnerships",
                    after: "Built the partner pipeline that added 14 accounts in 3 months",
                    explanation: "Names the outcome and the timeframe."
                )
            ],
            confidenceChecklist: [
                ConfidenceItem(title: "Contact details present", isComplete: true),
                ConfidenceItem(title: "Quantified impact", isComplete: false, explanation: "No numbers in the most recent role."),
            ]
        )
    }

    var body: some View {
        NavigationStack {
            ResumeDiagnosisView(
                viewModel: ResumeDiagnosisViewModel(
                    optimizationId: "smoke",
                    diagnosis: fixture
                ),
                onImprove: {},
                onEditTargetJob: {}
            )
            .environment(appState)
        }
        .task {
            if wantsHebrew { LocalizationManager.shared.setLanguage(.hebrew) }
        }
    }
}
#endif
