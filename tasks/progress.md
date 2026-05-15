# Project Progress

Project: ResumeBuilder iOS
Status: In Progress
Current Phase: Pre-release (TestFlight prep)
Active Story: —
Last Completed Story: Spec "Merge Track→Me, Redesign Optimised Resume, Real Resume Library" — all 5 stories (2026-05-15)
Next Recommended Story: Simulator smoke test + flip BackendConfig.useMockLibraryService once web API ships; then TestFlight build prep
Estimated Completion: 25%
Blockers: —
Risks: Swift 6 concurrency strictness; PDF render via WKWebView (fragile on real device); no Hebrew/RTL support; Resume Library backend endpoints not yet live (mocks active)
Last Validation: Xcode build succeeded after each story commit
Last Updated: 2026-05-15
Current Branch: claude/hungry-chatelet-a86030
Latest Commit: feat(library): resume library — mock-first save, picker, and cleanup of single-slot cache
Active Spec: —
Latest QA Report: —

## Tab Structure (as of 2026-05-15)
| Tab | Index | View | VM |
|-----|-------|------|----|
| Tailor | 0 | TailorView | TailorViewModel (stable @State) |
| Optimized | 1 | OptimizedResumeTabView → OptimizedResumeView | OptimizedResumeViewModel (built from appState.latestOptimizationId) |
| Design | 2 | RedesignResumeView | DesignViewModel (stable @State) |
| Expert | 3 | ExpertTabView → ExpertModesView | ExpertModesViewModel (built from appState.latestOptimizationId) |
| Me | 4 | ProfileView (with inline applications) | — |

## Key Shared State
- `AppState.latestOptimizationId: String?` — persisted via UserDefaults; set on optimize success; drives Optimized+Expert tabs
- `BackendConfig.useMockLibraryService = true` — flip to `false` once `/api/v1/resumes` ships on backend

## Files Deleted This Spec
- `Features/Score/ScoreView.swift`
- `Features/Score/ScoreViewModel.swift`
- `Features/V2/Profile/ProfileViewV2.swift`
- `Features/Track/ApplicationsListView.swift`

Notes: App is pre-release v1.0 build 1. V2 folder is active target for all new screens. Dark mode only. No App Store submission yet.
