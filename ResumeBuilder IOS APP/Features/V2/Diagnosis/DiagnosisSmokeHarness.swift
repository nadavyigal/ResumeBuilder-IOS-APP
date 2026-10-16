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

    /// `--smoke-fit` renders the fit check that now sits between optimizing
    /// and accepting, using the same numbers the backend returns.
    private var wantsFitCheck: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-fit")
    }

    private var fitFixture: OptimizeFitPreview {
        OptimizeFitPreview(
            currentScore: 29,
            potentialScore: 48,
            delta: 19,
            displayScores: true,
            confidence: 0.8,
            scoreVersion: "ats_v2.1_wp45",
            topGaps: [
                OptimizeFitGap(title: "Add at least one metric to your most recent role", estimatedGain: 6, category: "metrics"),
                OptimizeFitGap(title: "Include timeframes showing speed of delivery", estimatedGain: 4, category: "content"),
                OptimizeFitGap(title: "Mirror the posting's job title wording", estimatedGain: 3, category: "keywords"),
            ]
        )
    }

    /// `--smoke-confirm` renders the "Add only if true" sheet (G2b) with the
    /// claims the web guard held back on the Maya fixture (2026-10-12).
    private var wantsConfirm: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-confirm")
    }

    private var confirmFixture: [ReviewChangeGroupDTO] {
        let json = """
        {"review": {"id": "smoke", "grouped_changes_json": [
          {"id": "experience", "section": "experience", "title": "Experience", "summary": "", "before_excerpt": "", "after_excerpt": ""},
          {"id": "confirm-1", "section": "experience", "title": "Add only if true", "summary": "",
           "before_excerpt": "Built weekly sales dashboards in Looker.",
           "after_excerpt": "Built weekly sales dashboards in Looker and presented insights to non-technical stakeholders.",
           "confirm": {"requires": "experience", "kept": "Built weekly sales dashboards in Looker.",
                       "proposed": "Built weekly sales dashboards in Looker and presented insights to non-technical stakeholders.",
                       "terms": ["non-technical stakeholders"], "estimated_gain": 3}},
          {"id": "confirm-2", "section": "experience", "title": "Add only if true", "summary": "",
           "before_excerpt": "", "after_excerpt": "Owned the weekly KPI report for sales leadership.",
           "confirm": {"requires": "experience", "kept": null,
                       "proposed": "Owned the weekly KPI report for sales leadership.",
                       "terms": ["sales leadership"], "estimated_gain": null}}
        ]}}
        """
        let envelope = try? JSONDecoder().decode(OptimizationReviewEnvelope.self, from: Data(json.utf8))
        return envelope.map(ConfirmPhraseSelection.claims(in:)) ?? []
    }

    var body: some View {
        if wantsConfirm {
            // The sheet brings its own NavigationStack.
            AddOnlyIfTrueView(claims: confirmFixture, onContinue: { _ in }, onCancel: {})
                .task {
                    if wantsHebrew { LocalizationManager.shared.setLanguage(.hebrew) }
                }
        } else {
            standardBody
        }
    }

    private var standardBody: some View {
        NavigationStack {
            if wantsFitCheck {
                OptimizeFitCheckView(
                    fit: fitFixture,
                    jobTitle: "Business Development Manager · XTEND",
                    onAccept: {},
                    onEditTargetJob: {}
                )
            } else {
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
        }
        .task {
            if wantsHebrew { LocalizationManager.shared.setLanguage(.hebrew) }
        }
    }
}
#endif
