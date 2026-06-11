# Project Progress

Project: ResumeBuilder iOS
Status: In Progress
Current Phase: Pre-release (TestFlight prep)
Active Story: —
Last Completed Story: Fix optimize 500 error + Profile page not loading history (2026-05-18)
Next Recommended Story: Simulator smoke test — Me tab shows history + Optimize with valid PDF flows normally; then flip BackendConfig.useMockLibraryService once web API ships
Estimated Completion: 28%
Blockers: Backend PDF fix (PR #57 in new-ResumeBuilder-ai-) needs to be deployed to production for the 422 fix to take effect server-side
Risks: Swift 6 concurrency strictness; PDF render via WKWebView (fragile on real device); no Hebrew/RTL support; Resume Library backend endpoints not yet live (mocks active)
Last Validation: git pull origin main ran in main project dir — 3 files updated to commit 01bfecb
Last Updated: 2026-05-18
Current Branch: main (main project dir at 01bfecb after pull)
Latest Commit: fix(profile): isActive reload + APIClient JSON error parsing + PDF parse 422
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
