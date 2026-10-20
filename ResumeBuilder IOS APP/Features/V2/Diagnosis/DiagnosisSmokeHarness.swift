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

    /// The founder's device run of 2026-10-19: stored 45 before tailoring and
    /// 67 after. Its review projected 49, which the screen used to show as the
    /// match; `changesFixture` carries that projection so a regression is
    /// visible here. Gap text deliberately repeats the title in the
    /// explanation for the first item, so the de-duplication is visible too.
    private var fixture: ResumeDiagnosis {
        ResumeDiagnosis(
            matchScore: 67,
            potentialScore: nil,
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
            ],
            startingScore: 45
        )
    }

    /// The review behind that run, as the server stores it: section keys in
    /// lower case and an `ats_preview_json` projection of 45 -> 49.
    private var changesFixture: OptimizationReviewEnvelope? {
        let json = """
        {"review": {"id": "smoke", "ats_preview_json": {"before": 45, "after": 49, "delta": 4},
          "grouped_changes_json": [
            {"id": "summary", "section": "summary", "title": "Sharper professional summary",
             "summary": "Clarifies your value proposition for the target role.",
             "before_excerpt": "Sales manager with B2B experience.",
             "after_excerpt": "Business development manager who built a B2B partner pipeline."},
            {"id": "skills", "section": "skills", "title": "Prioritized role-relevant skills",
             "summary": "Highlights the strongest keywords and core capabilities first.",
             "before_excerpt": "Excel, CRM", "after_excerpt": "Partnerships, pipeline management, CRM"}
          ]}}
        """
        return try? JSONDecoder().decode(OptimizationReviewEnvelope.self, from: Data(json.utf8))
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

    /// `--smoke-confirm-flow` mounts the sheet the way Home does, on the stack, and
    /// starts `PhraseConfirmationFlow` with the fixture: with no destination (Home's
    /// direct-apply path, no fit preview), or over a pushed one with `--smoke-fit`.
    private var wantsConfirmFlow: Bool {
        ProcessInfo.processInfo.arguments.contains("--smoke-confirm-flow")
    }

    var body: some View {
        if wantsConfirmFlow {
            ConfirmFlowSmoke(claims: confirmFixture, overPushedDestination: wantsFitCheck)
        } else if wantsConfirm {
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
                onEditTargetJob: {},
                previewChanges: changesFixture
            )
            .environment(appState)
            }
        }
        .task {
            if wantsHebrew { LocalizationManager.shared.setLanguage(.hebrew) }
        }
    }
}
/// The stack-level sheet, driven by the real flow and a fake backend.
private struct ConfirmFlowSmoke: View {
    let claims: [ReviewChangeGroupDTO]
    let overPushedDestination: Bool
    @State private var flow = PhraseConfirmationFlow()
    @State private var pushed: String?
    @State private var applied = "nothing applied"

    var body: some View {
        NavigationStack {
            Text(verbatim: "Home root · \(applied)")
                .navigationDestination(item: $pushed) { _ in Text(verbatim: "Fit check (pushed)") }
        }
        .phraseConfirmationSheet(flow) { pending, confirmed in
            Task {
                let result = try? await flow.finish(pending, confirmed: confirmed, backend: backend)
                applied = "applied \(result?.optimizationId ?? "-") with \(confirmed.count) confirmed"
            }
        }
        .task {
            if overPushedDestination {
                pushed = "fit"
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
            _ = try? await flow.start(reviewId: "smoke", backend: backend)
        }
    }

    private var backend: PhraseConfirmationBackend {
        let json = """
        {"review": {"id": "smoke", "grouped_changes_json": [
          {"id": "experience", "section": "experience", "title": "Experience", "summary": "", "before_excerpt": "", "after_excerpt": ""}
        ]}}
        """
        let base = try! JSONDecoder().decode(OptimizationReviewEnvelope.self, from: Data(json.utf8))
        let claims = self.claims
        return PhraseConfirmationBackend(
            load: { _ in
                // The fixture's claims plus their experience change.
                let groups = """
                {"review": {"id": "smoke", "grouped_changes_json": [
                  {"id": "experience", "section": "experience", "title": "Experience", "summary": "", "before_excerpt": "", "after_excerpt": ""},
                  {"id": "confirm-1", "section": "experience", "title": "Add only if true", "summary": "",
                   "before_excerpt": "", "after_excerpt": "",
                   "confirm": {"requires": "experience", "kept": "\(claims.first?.confirm?.kept ?? "")",
                               "proposed": "\(claims.first?.confirm?.proposed ?? "")", "terms": [], "estimated_gain": 3}}
                ]}}
                """
                return (try? JSONDecoder().decode(OptimizationReviewEnvelope.self, from: Data(groups.utf8))) ?? base
            },
            apply: { _, envelope, _ in
                OptimizationAutoApplyService.Result(optimizationId: "smoke-opt", envelope: envelope, flaggedGroupIds: [])
            }
        )
    }
}
#endif

