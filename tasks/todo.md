# Current Task

**Objective:** Merge Track→Me, Redesign Optimized Resume, Real Resume Library (Stories 1–5)
**Status:** COMPLETE ✅
**Spec:** See plan in `/Users/nadavyigal/.claude/plans/implement-story-1-first-partitioned-mist.md`

## Execution Order
1. [x] Story 1 — Tab restructure (Tailor/Optimized/Design/Expert/Me) ✅
2. [x] Story 3 — Combine Score+Tailor; set appState.latestOptimizationId on optimize ✅
3. [x] Story 2 — Optimized Resume page: preview-first, no section boxes ✅
4. [x] Story 5 — Me page: applications inline, drop ProfileViewV2 ✅
5. [x] Story 4 — Resume library: backend + save-prompt + picker (mocks first) ✅

## Story 3 Checklist — Combine Score + Tailor
- [x] Port `runFreeATS` from `ScoreViewModel` into `TailorViewModel`
- [x] Add `atsResult: ATSScoreResult?` property to `TailorViewModel`
- [x] Add `onSwitchTab: (ResumlyTab) -> Void` param to `TailorView`
- [x] Branch optimize button on `appState.isAuthenticated`: unauth → free ATS, auth → optimize
- [x] On optimize success: set `appState.latestOptimizationId`; call `onSwitchTab(.optimized)`
- [x] Remove `NavigationLink(... shouldNavigate)` block from `TailorView`
- [x] Delete `Features/Score/ScoreView.swift`
- [x] Delete `Features/Score/ScoreViewModel.swift`
- [x] Xcode build passes

## Story 2 Checklist — Optimized Resume preview-first
- [x] Strip `ForEach(viewModel.sections) { ResumeSectionCard }` from `OptimizedResumeView`
- [x] Add inline `ResumePreviewWebView` with aspect ratio 8.5:11
- [x] Replace bottom bar with Refine / Send to Expert / Open Design buttons
- [x] Update `OptimizedResumeTabView` to use real `OptimizedResumeView`
- [x] Xcode build passes

## Story 5 Checklist — Me + applications inline
- [x] Add `applicationsSection` to `ProfileView` using `ApplicationsViewModel`
- [x] Delete `Features/V2/Profile/ProfileViewV2.swift`
- [x] Delete `Features/Track/ApplicationsListView.swift`
- [x] Xcode build passes

## Story 4 Checklist — Resume library (mocks)
- [x] Add `SavedResume` model
- [x] Add Endpoints cases: savedResumes / saveResume / deleteResume / renameResume
- [x] Create `ResumeLibraryService` (real + mock)
- [x] Create `ResumeLibraryViewModel`
- [x] Add save prompt after upload in TailorView
- [x] Create `SavedResumePickerSheet`
- [x] Remove legacy single-slot cache from TailorViewModel
- [x] Xcode build passes

## Post-Implementation TODOs
- [ ] Simulator smoke test all 5 tabs
- [ ] Flip `BackendConfig.useMockLibraryService = false` once web API ships `/api/v1/resumes`
- [ ] Create PR: `claude/hungry-chatelet-a86030` → `main`
