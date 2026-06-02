# Current Task

**Objective:** Implement Phase 2 of the Next Move Plan: submit package with optimized resume + cover letter from Optimized/Track
**Status:** Complete
**Spec:** Pasted plan from Codex attachment `e491b2b3-9a66-485e-8ef8-cc4706fa1954`
**Branch:** `main`

## Scope
- Add application creation to `ResumeBuilder IOS APP/Core/API/ApplicationTrackingService.swift`.
- Add application create DTOs to `ResumeBuilder IOS APP/Core/API/Models/DomainModels.swift`.
- Add a `@Observable @MainActor` submit/package view model in `ResumeBuilder IOS APP/Features/V2/Improve/`.
- Add an Optimized resume submit sheet/action in `ResumeBuilder IOS APP/Features/V2/Improve/OptimizedResumeView.swift`.
- Reuse `OptimizedResumeViewModel.downloadPDF`, `ExpertWorkflowService.run/apply`, `ApplicationTrackingService.attachOptimized/markApplied/saveExpertReport`.
- Add focused tests for create payload/body and submit/package orchestration.

## Story Checklist
- [x] Add test coverage for application create request body/decoding.
- [x] Add test coverage for submit-package orchestration success/failure.
- [x] Implement application create DTOs and `ApplicationTrackingService.createApplication`.
- [x] Implement `SubmitApplicationViewModel`.
- [x] Add Optimized submit package sheet with job/company/source inputs and result actions.
- [x] Run focused tests.
- [x] Run Xcode build.
- [x] Run full tests.
- [x] Simulator smoke test launch/package UI as far as local auth state allows.
- [x] Update `tasks/todo.md`, `tasks/progress.md`, and `tasks/session-log.md`.

## Validation
- Focused `OptimizedResumeViewModelTests` passed 11/11 on iPhone 17 simulator.
- `xcodebuild build` succeeded on iPhone 17 simulator using `/tmp/resumebuilder-derived`.
- Full `xcodebuild test` passed 66 XCTest tests plus 5 Swift Testing tests using `/tmp/resumebuilder-derived`.
- `simctl` install/launch smoke succeeded on booted iPhone 17; Home screenshot rendered cleanly at `/tmp/resumebuilder-smoke/phase2-submit-package-launch-late.png`.
- Package sheet was not live-smoked end-to-end because the local simulator was unauthenticated and had no persisted real optimization id.

## Out of Scope
- Automatic submission to third-party job sites.
- Backend optimization quality / ATS scoring changes.
- Resume Library backend route.
- New dependencies.
