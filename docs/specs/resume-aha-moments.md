# Feature Spec — Resume Aha Moments

**Date:** 2026-06-12
**Status:** Approved
**Brief:** `docs/specs/drafts/resume-aha-moments-brief.md`

---

## Objective
We are building a Resume Diagnosis and confidence layer so that job seekers can quickly understand their resume-job fit, see concrete fixes, and move into optimization/export with confidence.

## User Story
As a job seeker, I want a recruiter-style diagnosis for my resume against a target job so that I know what is missing, what improved, and what to do next.

## Acceptance Criteria
- [ ] User can reach Resume Diagnosis from the current V2 Home/Tailor resume + job flow.
- [ ] Diagnosis has loading, success, empty, and error states.
- [ ] Diagnosis shows match score guidance, potential optimized score when available, top 3 gaps, missing keywords grouped by priority, recruiter-eye review, before/after rewrite, and CTA.
- [ ] `BeforeAfterRewriteCard` handles missing original bullet without showing fake before text.
- [ ] `RecruiterEyeViewCard` uses direct, non-scary copy and avoids outcome guarantees.
- [ ] `ResumeConfidenceChecklist` appears after optimization or in preview/export context.
- [ ] Empty states explain the value of uploading a resume and adding a job in one primary action.
- [ ] All new screens/components live under `Features/V2/`.
- [ ] New models are `Codable`, `Equatable`, and `Sendable` where appropriate.
- [ ] No new SPM packages are introduced.
- [ ] Xcode build succeeds, relevant tests pass, and simulator smoke validates iPhone 17 plus small-iPhone readability.

## Implementation Notes
- v1 has no backend dependency. It prefers an optional backend `diagnosis` payload when present, then derives grounded fallback copy from optimization detail, ATS scores, sections, and ATS blockers.
- Score language must say guidance/estimated and must not promise ATS pass, interviews, or outcomes.
- Missing original bullets should be shown as unavailable rather than fabricated.

## iOS Changes

### New Files
| File | Purpose |
|------|---------|
| `ResumeBuilder IOS APP/Models/ResumeDiagnosis.swift` | Diagnosis models and safe mapper. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeDiagnosisView.swift` | Main diagnosis screen. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeDiagnosisViewModel.swift` | Diagnosis loader and UI state. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/BeforeAfterRewriteCard.swift` | Reusable before/after card. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/RecruiterEyeViewCard.swift` | Reusable recruiter review card. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeConfidenceChecklist.swift` | Reusable confidence checklist. |
| `ResumeBuilder IOS APPTests/ResumeDiagnosisViewModelTests.swift` | Focused mapping tests. |

### Modified Files
| File | Change |
|------|--------|
| `ResumeBuilder IOS APP/Core/API/Models/DomainModels.swift` | Decode optional backend diagnosis from optimization detail. |
| `ResumeBuilder IOS APP/ViewModels/OptimizedResumeViewModel.swift` | Expose diagnosis from loaded detail. |
| `ResumeBuilder IOS APP/Features/V2/Home/HomeActivationState.swift` | Aha-focused empty state copy. |
| `ResumeBuilder IOS APP/Features/V2/Home/HomeTabView.swift` | Route optimization completion to Diagnosis. |
| `ResumeBuilder IOS APP/Features/Tailor/TailorView.swift` | Mirror Diagnosis route. |
| `ResumeBuilder IOS APP/Features/V2/Home/ResumeOptimizationLoadingView.swift` | Diagnosis-oriented loading messages. |
| `ResumeBuilder IOS APP/Features/V2/Improve/OptimizedResumeView.swift` | Add compact diagnosis and confidence checklist. |

## Development Stories
1. Diagnosis models and mapper.
2. Reusable aha components.
3. Resume Diagnosis screen and navigation.
4. Smart empty/loading states and confidence checklist integration.
5. Verification and Agent OS handoff.

## Out of Scope
- Backend AI prompt changes.
- Paywall redesign.
- Export PDF rendering changes.
- New SPM packages.
