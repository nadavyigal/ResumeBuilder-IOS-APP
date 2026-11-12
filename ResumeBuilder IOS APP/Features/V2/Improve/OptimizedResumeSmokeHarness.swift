#if DEBUG
import SwiftUI

/// Renders `OptimizedResumeView` with fixture data.
///
/// The Optimized screen sits behind sign-in and a completed optimization, so it
/// cannot be reached in a simulator without an account. This harness makes the
/// first screen (résumé card, score panel, pinned export bar) reviewable,
/// including in Hebrew RTL with `--smoke-he`.
///
/// DEBUG only, reached via `--smoke-optimized`, following the same convention
/// as `--smoke-diagnosis`. It ships in no Release build. Fictional data.
struct OptimizedResumeSmokeHarness: View {
    @State private var appState = AppState()
    @State private var viewModel = OptimizedResumeViewModel(
        optimizationId: "smoke-optimized-001",
        sections: [
            OptimizedResumeSection(
                id: "summary",
                type: .summary,
                body: "Data analyst with 6 years in SaaS reporting. Builds SQL and Looker dashboards that sales and finance teams use every week.",
                status: "optimized"
            ),
            OptimizedResumeSection(
                id: "experience",
                type: .experience,
                body: "Data Analyst, Northwind Media (2021 to Present)\n• Built SQL dashboards that cut monthly reporting time by 40%.\n• Partnered with sales leads to define pipeline metrics.\n\nBI Analyst, Contoso Retail (2018 to 2021)\n• Automated weekly revenue reports in Python.\n• Cleaned and modelled order data for 12 regional stores.",
                status: "improved"
            ),
            OptimizedResumeSection(
                id: "skills",
                type: .skills,
                body: "SQL, Python, Looker, Excel, dbt, stakeholder reporting",
                status: "optimized"
            ),
            OptimizedResumeSection(
                id: "education",
                type: .education,
                body: "B.Sc. Information Systems, Ben Gurion University",
                status: "unchanged"
            ),
        ],
        atsScoreBefore: 64,
        atsScoreAfter: 72,
        jobTitle: "Senior Data Analyst",
        company: "Example Corp",
        contact: ResumeContact(
            name: "Dana Levi",
            email: "dana@example.test",
            phone: nil,
            location: "Tel Aviv",
            title: nil,
            linkedin: nil,
            portfolio: nil
        ),
        optimizationService: MockResumeOptimizationService()
    )

    var body: some View {
        NavigationStack {
            OptimizedResumeView(viewModel: viewModel, showsNextSteps: true)
        }
        .environment(appState)
        .task {
            if ProcessInfo.processInfo.arguments.contains("--smoke-he") {
                LocalizationManager.shared.setLanguage(.hebrew)
            }
        }
    }
}
#endif
