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
- [x] Remove runtime mock service flags and mock optimize path
- [x] Add regression tests for live-only runtime services and stale mock optimization cleanup
- [x] Disable missing Resume Library route gracefully in iOS runtime
- [x] Add PDF upload preflight and PDF multipart content type
- [x] Quiet benign preview cancellation and avoid initial empty preview render before section load
- [x] XcodeBuildMCP build + test pass on iPhone 17 Pro simulator (24/24)
- [x] Confirm local checkout is on merged `main` base, not the stale Codex branch
- [x] Stop automatic `/api/v1/styles/history` calls while the backend route returns 500
- [x] Reject malformed/scanned/no-readable-text PDFs locally before optimize upload
- [x] XcodeBuildMCP build + test pass on iPhone 17 Pro simulator (25/25)
- [x] Pull merged PR #26 into local `main` so Xcode no longer builds stale code
- [x] Generate a backend-readable text-layer PDF before live upload to avoid backend PDF parser 422s
- [x] XcodeBuildMCP build + test pass on iPhone 17 Pro simulator after upload normalization (25/25)
- [x] Fix Design Apply payload to send backend-required `templateId`
- [x] Include iOS-extracted `resumeText` in optimize multipart uploads
- [x] Add backend `/api/upload-resume` parser fallback to use valid `resumeText` when PDF parsing fails
- [x] Cache design templates and skip duplicate preview renders/detail fetches
- [x] Add Xcode rebuild branch/HEAD checklist to iOS QA checklist
- [x] XcodeBuildMCP build + test pass on iPhone 17 Pro simulator after end-to-end stabilization (24 XCTest + 5 Swift Testing)
- [x] Backend upload fallback Jest contract passes (4/4)
- [x] Preserve optimized resume contact data in backend detail + iOS preview/copy fallback
- [x] Resolve design template UUIDs to category/slug for backend preview/export rendering
- [x] Reload applied design assignment into Optimized preview after Apply/Undo
- [x] Send Expert Center user evidence input and force no-cache optimized resume/ATS refresh after Expert Apply
- [x] XcodeBuildMCP build + test pass after optimize/design/expert repair (32/32)
- [x] Backend focused Jest contracts pass for iOS optimization/design + expert run/apply (7/7)
- [x] Fix Design category switching so current assignment reload no longer snaps the UI back to Traditional
- [x] Make optimized preview show local rendered HTML immediately while backend design HTML loads/caches in the background
- [x] XcodeBuildMCP build + test pass after preview/category follow-up (33/33)
- [x] Stop optimized preview from blocking on section-detail load before starting render-preview
- [x] XcodeBuildMCP build + test pass after preview loading follow-up (33/33)
- [x] Align iOS Expert structured parsing with backend-real workflow JSON shapes
- [x] Show extra Expert rationale/evidence/confidence fields in type-specific iOS output views
- [x] Initialize/clamp Expert summary and cover-letter selection indices before apply
- [x] XcodeBuildMCP build + test pass after Expert contract alignment (55/55)
- [x] Backend expert prompts and validators tightened for evidence provenance, keyword stuffing, bloated summaries, and missing section contracts
- [x] Backend focused expert Jest contracts pass after output-quality follow-up (23/23)
- [ ] Backend: implement `/api/v1/resumes` list/save/rename/delete/download with JSON errors
- [ ] Backend: fix `/api/v1/styles/history` or document it as unavailable for iOS
- [ ] Real-device smoke test with live account and known-good text-based PDF exported from a word processor
- [ ] Create PR(s) for the end-to-end live stabilization changes
