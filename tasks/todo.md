# Current Task

**Objective:** Implement the ResumeBuilder post-optimization upgrade: stronger optimization contract, focused manual amend UX, ATS uplift loop, and Me application package hub.
**Status:** Complete
**Spec:** User-approved plan pasted on 2026-06-02
**Branch:** `main`

## Scope
- Update iOS optimize requests to ask the backend for `strong_faithful` optimization by default.
- Add iOS decoding support for richer ATS diagnostics and application package artifacts when the backend returns them.
- Polish Optimized manual editing into a focused section editor with dirty-state protection and empty-section validation.
- Add an ATS uplift action that uses the existing Expert ATS workflow/apply path, then refreshes sections and ATS scores.
- Upgrade Me/Application Detail into an assisted submit package hub with resume, cover letter, job link, score, and status actions.
- Keep assisted submit only; no third-party auto-apply.

## Story Checklist
- [x] Add contract/model tests for strong optimization mode and package/ATS decoding.
- [x] Send strong-but-faithful optimization mode in `/api/optimize`.
- [x] Add ATS blocker/supporting models for optimization detail.
- [x] Add application package artifact decoding for cover-letter report content/link fields.
- [x] Replace inline manual edit panel with focused section editor sheet.
- [x] Add ATS status/blockers panel and Improve ATS action.
- [x] Add Me application package hub actions and cover-letter display.
- [x] Run focused tests.
- [x] Run Xcode build.
- [x] Run full tests.
- [x] Simulator smoke test as far as local auth state allows.
- [x] Update `tasks/todo.md`, `tasks/progress.md`, and `tasks/session-log.md`.

## Validation
- Focused `OptimizedResumeViewModelTests` passed 15/15 on iPhone 17 simulator.
- `xcodebuild build` succeeded on iPhone 17 simulator using `/tmp/resumebuilder-derived`.
- Full `xcodebuild test` passed 70 XCTest tests plus 5 Swift Testing tests using `/tmp/resumebuilder-derived`.
- `simctl` install/launch smoke succeeded on booted iPhone 17; late Home screenshot rendered cleanly at `/tmp/resumebuilder-smoke/post-optimization-upgrade-iphone17-late.png`.
- iPhone SE simulator and authenticated live package/edit smoke were not available in this environment.

## Out of Scope
- Backend implementation of the optimizer itself; this workspace contains the iOS app only.
- Automatic submission to third-party job sites.
- New dependencies.
- Resume Library backend route.
