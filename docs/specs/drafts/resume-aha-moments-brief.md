# Product Brief — Resume Aha Moments

**Date:** 2026-06-12
**Author:** Codex
**Status:** Draft

---

## Problem
Job seekers currently upload a resume and target job, then mostly see optimization and ATS surfaces after the work is already done. The first-session value can feel abstract: the app says it optimizes, but it does not immediately package the diagnosis in a recruiter-style way that explains why the resume is weak or strong for this specific job.

## Solution
Add a compact Resume Diagnosis experience after resume + job input that shows match score guidance, top gaps, missing keywords, recruiter-eye feedback, one before/after rewrite, and a clear next action. Reuse the same components later in optimization preview and export/payment confidence moments.

## User Story
As a job seeker, I want to see why my resume does or does not match a specific job so that I understand what to fix and trust the optimized version before exporting.

## Scope (In)
- Resume Diagnosis screen/component reachable from the current Home/Tailor optimize flow.
- Reusable `BeforeAfterRewriteCard`, `RecruiterEyeViewCard`, and `ResumeConfidenceChecklist` SwiftUI components.
- Lightweight diagnosis models and mapper/fallback logic from existing optimization detail, ATS blockers, ATS scores, review changes, quick wins, and mock data.
- Smart empty-state copy for missing resume/job inputs in the V2 activation flow.
- Loading, success, empty, and error states.
- Grounded language: scores are guidance, not guarantees.

## Scope (Out)
- Long tutorial onboarding.
- New SPM packages.
- New auth, payment, or StoreKit behavior.
- New backend endpoint as a blocker for v1.
- Claims that the resume will pass ATS, get interviews, or produce guaranteed outcomes.
- Hebrew/RTL support.

## Success Metrics
- A new user can reach a diagnosis from resume + job input within the normal first-session flow.
- The diagnosis explains at least one score, three gaps/actions, missing keyword coverage, recruiter impression, and one concrete rewrite.
- The primary CTA moves the user to the existing improvement/optimization path.
- Existing optimize/export flows remain intact.
- Xcode build and focused tests pass; simulator smoke validates small iPhone readability.

## Open Questions
1. Should Resume Diagnosis appear before running full optimization for authenticated users, or immediately after optimization detail loads with “before/potential after” framing?
2. Should guest users see a lighter diagnosis from public ATS data, or should the full diagnosis remain signed-in only?
3. Does the backend already return original bullet excerpts in optimization detail, or should v1 derive a conservative before/after from review groups/quick wins when available?

## Risks
- Backend data shape may not include enough original-resume evidence for a true before/after rewrite; v1 must avoid fabricating specifics.
- Adding another screen between optimize and preview may slow the core flow if the CTA is not direct.
- Swift 6 strict concurrency requires all new models to be `Sendable` and ViewModels/components to stay actor-safe.
- Active optimization-detail work means the plan should extend `Features/V2/Improve` and existing detail DTOs rather than creating a parallel data path.
