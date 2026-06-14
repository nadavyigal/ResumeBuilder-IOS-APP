# Feature Spec — Resume Aha Moments

**Date:** 2026-06-12
**Status:** Draft
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

## Existing App Findings
- `HomeTabView` is the guest-first activation surface and already derives input states through `HomeActivationState`.
- `TailorView` and `TailorViewModel` own resume upload, job input, public ATS, and authenticated optimization.
- `ResumeOptimizationLoadingView` already has progress messaging that can be updated to the requested diagnosis language.
- `OptimizedResumeView` already loads `OptimizationDetailDTO`, ATS before/after scores, job context, `atsBlockers`, sections, and export actions.
- Existing `ATSOptimizationBlocker`, `ATSAuthQuickWinSuggestion`, `QuickWin`, and `ReviewChangeGroupDTO` can seed diagnosis content without inventing claims.
- `ImproveView` already displays ATS analysis, missing keywords, quick wins, and the "Optimize for This Job" action, but it is not the main activation route.

## API Changes

### New Endpoints
None required for v1.

### Modified Endpoints
No hard dependency for v1. If backend support is later added, extend `GET /api/v1/optimizations/[id]` to optionally return a `diagnosis` object.

### Optional Future Response Shape
```json
{
  "diagnosis": {
    "match_score": 54,
    "potential_score": 82,
    "top_gaps": [
      {
        "title": "Missing product analytics keywords",
        "explanation": "The job emphasizes analytics ownership, but the resume only mentions reporting.",
        "severity": "high"
      }
    ],
    "missing_keywords": [
      {
        "keyword": "product analytics",
        "importance": "high",
        "reason": "Appears in the role requirements"
      }
    ],
    "recruiter_review": {
      "impression": "Strong operations background, but the resume does not yet prove product ownership.",
      "strengths": ["Finance", "Stakeholder work", "Process improvement"],
      "concerns": ["Missing metrics", "Weak role targeting"],
      "next_fix": "Rewrite the summary around the target job."
    },
    "before_after": [
      {
        "before": "Responsible for reports",
        "after": "Built weekly reporting workflows that helped leadership identify churn risks and prioritize renewal actions.",
        "explanation": "Stronger because it adds action, business context, and measurable impact."
      }
    ],
    "confidence_checklist": [
      {
        "title": "Includes priority keywords",
        "is_complete": true,
        "explanation": "Adds truthful target-role terms from the job post."
      }
    ]
  }
}
```

## iOS Changes

### New Files
| File | Purpose |
|------|---------|
| `ResumeBuilder IOS APP/Models/ResumeDiagnosis.swift` | Lightweight diagnosis domain models, enums, mock sample, and safe fallback helpers. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeDiagnosisView.swift` | Main diagnosis screen with loading/success/empty/error states and CTA callbacks. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeDiagnosisViewModel.swift` | `@Observable @MainActor` mapper/loading state from optimization detail or mock/fallback diagnosis. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/BeforeAfterRewriteCard.swift` | Reusable before/after bullet rewrite component. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/RecruiterEyeViewCard.swift` | Reusable recruiter 7-second review component. |
| `ResumeBuilder IOS APP/Features/V2/Diagnosis/ResumeConfidenceChecklist.swift` | Reusable confidence checklist component for post-optimization/export readiness. |
| `ResumeBuilder IOS APPTests/ResumeDiagnosisViewModelTests.swift` | Focused tests for mapping, fallback data, missing-before handling, and grounded score labels. |

### Modified Files
| File | Change |
|------|--------|
| `ResumeBuilder IOS APP/Features/V2/Home/HomeActivationState.swift` | Replace generic activation copy with action-oriented aha copy for missing resume/job and ready states. |
| `ResumeBuilder IOS APP/Features/V2/Home/HomeTabView.swift` | Add primary "Analyze my resume" framing and route authenticated optimize completion to Diagnosis before Optimized when data is available. |
| `ResumeBuilder IOS APP/Features/Tailor/TailorView.swift` | Mirror diagnosis routing from the Tailor flow if the older Tailor tab remains reachable. |
| `ResumeBuilder IOS APP/Features/Tailor/TailorViewModel.swift` | Preserve enough upload/optimization context for diagnosis routing; do not change endpoint URLs directly. |
| `ResumeBuilder IOS APP/ViewModels/OptimizedResumeViewModel.swift` | Expose a computed diagnosis or source values for diagnosis mapping from loaded optimization detail. |
| `ResumeBuilder IOS APP/Core/API/Models/DomainModels.swift` | Optionally decode future `diagnosis` fields from `OptimizationDetailDTO` using flexible snake/camel keys. |
| `ResumeBuilder IOS APP/Features/V2/Improve/OptimizedResumeView.swift` | Add a compact diagnosis/aha section near the top and show `ResumeConfidenceChecklist` before export/payment actions. |
| `ResumeBuilder IOS APP/Features/V2/Home/ResumeOptimizationLoadingView.swift` | Update status messages to "Reading your resume", "Comparing against the job", "Finding missing signals", "Preparing recruiter-style feedback". |

### Navigation
- Primary v1 path: Home/Tailor resume + job input → optimize/review apply or direct optimization → Resume Diagnosis → "Improve my resume" opens existing Optimized tab/preview or existing Improve/Expert actions.
- Secondary action: "Edit target job" returns to Tailor/Home job input without clearing resume selection.
- If no optimization id exists, diagnosis shows an empty state with one primary action to upload/paste job.
- If optimization detail fails to load, diagnosis shows an error state and keeps a fallback CTA to existing Optimized tab when an optimization id exists.

## Data Model
Use models close to the draft but make identifiers deterministic-friendly for tests.

```swift
struct ResumeDiagnosis: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let matchScore: Int
    let potentialScore: Int?
    let scoreNote: String
    let topGaps: [ResumeGap]
    let missingKeywords: [ResumeKeyword]
    let recruiterReview: RecruiterReview
    let beforeAfter: [BulletRewrite]
    let confidenceChecklist: [ConfidenceItem]
}

struct ResumeGap: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let explanation: String
    let severity: GapSeverity
}

enum GapSeverity: String, Codable, Sendable {
    case high
    case medium
    case low
}

struct ResumeKeyword: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let keyword: String
    let importance: KeywordImportance
    let reason: String?
}

enum KeywordImportance: String, Codable, Sendable {
    case high
    case medium
    case low
}

struct RecruiterReview: Codable, Equatable, Sendable {
    let impression: String
    let strengths: [String]
    let concerns: [String]
    let nextFix: String
}

struct BulletRewrite: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let before: String?
    let after: String
    let explanation: String
}

struct ConfidenceItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let isComplete: Bool
    let explanation: String?
}
```

## Diagnosis Mapping Rules
- Prefer backend `diagnosis` if present in `OptimizationDetailDTO`.
- Otherwise derive safe diagnosis from:
  - `atsScoreBefore` as `matchScore`.
  - `atsScoreAfter` as `potentialScore`.
  - `atsBlockers.prefix(3)` as top gaps.
  - blocker titles/details containing keyword terms as missing keyword fallback.
  - `sections` and `jobTitle` for grounded recruiter review copy.
  - review groups/quick wins only when they contain both before and after excerpts.
- If original bullet is missing, `BeforeAfterRewriteCard` should label the before area as "Original bullet unavailable" and focus on the improved bullet/explanation.
- Score copy must say "guidance" or "estimated match", never "guaranteed".

## Development Stories
1. Story 1: Diagnosis models and mapper — estimated M
2. Story 2: Reusable aha components — estimated M
3. Story 3: Resume Diagnosis screen and navigation — estimated L
4. Story 4: Smart empty/loading states and confidence checklist integration — estimated M
5. Story 5: Tests, simulator smoke, and Agent OS progress updates — estimated M

## Open Questions
1. Should the first implementation route all authenticated users through Diagnosis, or only show it when the optimization detail has enough data?
2. Should the free public ATS result use the same `ResumeDiagnosisView` in a limited mode?
3. Should "Improve my resume" go to Optimized tab by default, or trigger the existing `Improve ATS` expert workflow when blockers are high severity?

## Out of Scope
- Backend AI prompt changes.
- Full paywall redesign.
- Export PDF rendering changes.
- Design template changes.
- Resume creation from scratch.
- New App Store screenshot work.
