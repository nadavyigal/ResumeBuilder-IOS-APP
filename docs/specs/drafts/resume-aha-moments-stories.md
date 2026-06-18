# Dev Stories — Resume Aha Moments

**Feature:** Resume Aha Moments
**Spec:** `docs/specs/drafts/resume-aha-moments-spec.md`
**Date:** 2026-06-12
**Status:** Draft

---

## Story 1 — Diagnosis Models and Mapper

**Size:** M (1–3h)
**Status:** Pending

### Objective
Create diagnosis models and deterministic mapping from existing optimization/ATS data so the UI can show a useful diagnosis without waiting for a new backend endpoint.

### Prerequisites
- Current optimization detail endpoint remains available.

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `ResumeBuilder IOS APP/Models/ResumeDiagnosis.swift` | Create | Add `Sendable` diagnosis models, sample data, and mapper helpers. |
| `ResumeBuilder IOS APP/ViewModels/OptimizedResumeViewModel.swift` | Modify | Expose source values or computed diagnosis input from loaded optimization detail. |
| `ResumeBuilder IOS APP/Core/API/Models/DomainModels.swift` | Modify | Optionally decode future `diagnosis` payload fields with flexible keys. |
| `ResumeBuilder IOS APPTests/ResumeDiagnosisViewModelTests.swift` | Create | Cover score labels, fallback blockers, missing before text, and keyword grouping. |

### Implementation Steps
1. Add the model file under `Models/` with `Codable`, `Equatable`, and `Sendable`.
2. Add a mapper that can build diagnosis from backend diagnosis or current optimization detail fields.
3. Keep fallback copy conservative and grounded.
4. Add focused unit tests for mapper behavior.

### Acceptance Criteria
- [ ] Models compile under Swift 6 strict concurrency.
- [ ] Mapper produces top gaps from `ATSOptimizationBlocker`.
- [ ] Mapper never fabricates a before bullet.
- [ ] Tests cover missing optional data.

### Test Plan
Run focused model/view-model tests plus `git diff --check`.

---

## Story 2 — Reusable Aha Components

**Size:** M (1–3h)
**Status:** Pending

### Objective
Build reusable SwiftUI cards for before/after rewrites, recruiter-eye review, and readiness confidence.

### Prerequisites
- Story 1 diagnosis models exist.

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/BeforeAfterRewriteCard.swift` | Create | Display original/improved bullet and explanation. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/RecruiterEyeViewCard.swift` | Create | Show impression, strengths, concerns, and next fix. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeConfidenceChecklist.swift` | Create | Show grounded readiness checklist. |

### Implementation Steps
1. Use existing design tokens: `AppColors`, `AppSpacing`, `AppTypography`, `AppRadii`, and `glassCard`.
2. Keep cards compact for small iPhones.
3. Add previews with mock diagnosis data.
4. Avoid scary language and guarantee claims in default copy.

### Acceptance Criteria
- [ ] Components render with full mock data.
- [ ] `BeforeAfterRewriteCard` handles nil/empty original bullet.
- [ ] Checklist language uses "more aligned" style copy.
- [ ] No hardcoded light-mode colors.

### Test Plan
Build and simulator smoke after integration.

---

## Story 3 — Resume Diagnosis Screen and Navigation

**Size:** L (3–6h)
**Status:** Pending

### Objective
Add the first "wow" diagnosis screen after the user provides resume + job context and optimization/detail data exists.

### Prerequisites
- Stories 1 and 2 are complete.

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeDiagnosisView.swift` | Create | Screen with loading, success, empty, and error states. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeDiagnosisViewModel.swift` | Create | `@Observable @MainActor` state loader/mapper. |
| `ResumeBuilder IOS APP/Features/V2/Home/HomeTabView.swift` | Modify | Route optimize success to diagnosis when appropriate. |
| `ResumeBuilder IOS APP/Features/Tailor/TailorView.swift` | Modify | Mirror route for existing Tailor entry point. |
| `ResumeBuilder IOS APP/App/MainTabViewV2.swift` | Modify | Pass tab-switch callbacks if needed for Diagnosis CTA. |

### Implementation Steps
1. Add `ResumeDiagnosisView` with score, gaps, keywords, recruiter-eye card, before/after card, and CTAs.
2. Load diagnosis from optimization detail by id; use mock/fallback only for previews or missing optional backend diagnosis.
3. Wire Home/Tailor optimize completion to show diagnosis before switching directly to Optimized, preserving review-apply behavior.
4. Implement "Improve my resume" to open the existing Optimized tab and "Edit target job" to return to input.

### Acceptance Criteria
- [ ] Authenticated user can reach Diagnosis after resume + job optimize flow.
- [ ] Diagnosis can also be opened from an existing optimization id.
- [ ] Error state keeps a useful next action.
- [ ] Empty state has one primary action.
- [ ] CTA does not break existing Optimized/Design/Expert navigation.

### Test Plan
Run focused tests and simulator smoke through Home/Tailor on iPhone 17.

---

## Story 4 — Smart Empty/Loading States and Confidence Checklist Integration

**Size:** M (1–3h)
**Status:** Pending

### Objective
Replace generic activation copy with action-oriented empty states and add the confidence checklist before export/payment moments.

### Prerequisites
- Stories 1 and 2 are complete.

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `ResumeBuilder IOS APP/Features/V2/Home/HomeActivationState.swift` | Modify | Add aha-focused copy for no resume/no job/ready states. |
| `ResumeBuilder IOS APP/Features/V2/Home/HomeTabView.swift` | Modify | Align primary CTA copy around "Analyze my resume". |
| `ResumeBuilder IOS APP/Features/Tailor/TailorView.swift` | Modify | Align old Tailor empty-state language if still reachable. |
| `ResumeBuilder IOS APP/Features/V2/Home/ResumeOptimizationLoadingView.swift` | Modify | Use diagnosis progress messages. |
| `ResumeBuilder IOS APP/Features/V2/Improve/OptimizedResumeView.swift` | Modify | Show `ResumeConfidenceChecklist` above export/submit package actions. |

### Implementation Steps
1. Update activation headlines/subheadlines with one-action value copy.
2. Update loading messages to match the requested four-step diagnosis language.
3. Add confidence checklist to optimized preview using diagnosis-derived or fallback checklist data.
4. Keep copy short and mobile-first.

### Acceptance Criteria
- [ ] Missing resume state explains recruiter 7-second value.
- [ ] Missing job state explains missing keyword reveal value.
- [ ] Loading state mentions reading, comparing, finding signals, and recruiter-style feedback.
- [ ] Checklist appears before export/payment actions without blocking export.

### Test Plan
Simulator smoke for no-resume, resume-no-job, optimizing, optimized-ready, and export states.

---

## Story 5 — Verification and Agent OS Handoff

**Size:** M (1–3h)
**Status:** Pending

### Objective
Verify the complete aha flow and update project memory after implementation.

### Prerequisites
- Stories 1–4 are complete.

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `tasks/todo.md` | Modify | Mark implemented story checklist items. |
| `tasks/progress.md` | Modify | Record completed story and validation evidence. |
| `tasks/lessons.md` | Modify if needed | Add lesson only for a real mistake, failed build pattern, or correction. |

### Implementation Steps
1. Run `git diff --check`.
2. Run focused tests for diagnosis and affected view models.
3. Run Xcode build/test command using a real installed simulator, preferably iPhone 17.
4. Smoke test the UI on iPhone 17 and a small iPhone target for readability.
5. Update Agent OS memory files with factual outcomes.

### Acceptance Criteria
- [ ] Xcode build succeeds.
- [ ] Relevant tests pass.
- [ ] Simulator smoke confirms diagnosis path and no layout clipping on small iPhone.
- [ ] `tasks/todo.md` and `tasks/progress.md` are updated after implementation.
- [ ] No lesson added unless a real failure/correction occurred.

### Test Plan
Use the repo README command with `-derivedDataPath /tmp/...`; clear duplicate `* 2.swift` files first if present per lessons.
