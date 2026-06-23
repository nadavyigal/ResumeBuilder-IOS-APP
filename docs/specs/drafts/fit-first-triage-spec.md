# Feature Spec — Fit-First Triage

**Date:** 2026-06-22
**Status:** Draft
**Brief:** `docs/specs/drafts/fit-first-triage-brief.md`

---

## Objective
Give the user an instant **Strong / Stretch / Skip** fit verdict (plus the decisive gaps) for a pasted job description before any optimization, so they invest effort only in winnable roles.

## User Story
As a job seeker evaluating a posting, I want an instant fit verdict and the few things standing between me and this job, so that I only invest effort in roles I can realistically win.

## Acceptance Criteria
- [ ] From the Tailor entry, the user pastes a JD and taps **Check Fit** (a new step before Optimize).
- [ ] Within a few seconds the user sees a verdict: **Strong**, **Stretch**, or **Skip**, with the underlying match %.
- [ ] The verdict screen lists the **3 decisive gaps** and **top missing keywords** for this job.
- [ ] The verdict screen offers **Optimize for this job** (routes into the existing diagnosis → Improve flow) and **Skip / not now**.
- [ ] A Fit verdict does **not** consume an optimization credit.
- [ ] Verdict copy is process-descriptive ("estimated fit vs this job"), never an outcome guarantee; no ATS-vendor claim.
- [ ] If no active resume exists, the screen routes the user to upload first (reuse existing upload preflight).
- [ ] Empty/too-short JD is rejected with friendly inline copy before any network call.
- [ ] Localized EN + HE; works in RTL.
- [ ] Analytics: `fit_check_started`, `fit_check_completed` (verdict, match_score), `fit_check_optimize_tapped`, `fit_check_skipped`.

## API Changes

**Decision (resolved):** no new endpoint. **Evolve the existing free ATS check `POST /api/public/ats-check`** (web repo `new-ResumeBuilder-ai-`) into the Fit check, then mirror it to iOS. iOS already calls this endpoint via `/api/public/ats-check`.

### Why this endpoint already fits
It is already: free, **anonymous** (`x-session-id`), **rate-limited** (5 checks / 7 days per IP), caches results in `anonymous_ats_scores`, accepts resume PDF + JD (paste **or** URL scrape), and runs `scoreResume` + `extractJob`. It already returns `score.overall`, ranked `suggestions`/`preview`, and `quickWins`, and `extractJob` already yields `must_have` requirements. The verdict band + decisive gaps are a **derivation** on top of these existing outputs, not new ML.

### Modified Endpoint — `POST /api/public/ats-check` (web)
Add fields to `formatResponse(...)` **additively** (do not remove or rename `score` / `preview` / `quickWins` / `checksRemaining` — the live web flow and the iOS public ATS path depend on them):
```jsonc
{
  // ...existing fields unchanged...
  "score": { "overall": 68, "timestamp": "..." },
  "preview": { "topIssues": [...], "totalIssues": 9, "lockedCount": 6 },
  "quickWins": [...],
  "checksRemaining": 4,

  // NEW (additive) — the Fit layer:
  "fit": {
    "verdict": "stretch",              // "strong" | "stretch" | "skip" — server-owned band
    "scoreNote": "Estimated fit vs this job, not a hiring guarantee.",
    "topGaps": [
      { "title": "No cloud infra experience", "detail": "JD lists AWS in must-have; not found in resume" }
    ],
    "missingKeywords": [
      { "keyword": "Terraform", "importance": "high" }   // from extractJob must_have not matched in resume
    ]
  }
}
```
- `verdict` band derived server-side from `score.overall` (Open Question 1: ≥75 strong / 50–74 stretch / <50 skip).
- `topGaps` / `missingKeywords` derived from `extractJob` `must_have` entries not matched in `resumeText` (the same data already powering `suggestions`).
- Web UI: the existing free-ATS-check page should render the verdict band on top of the current score/quick-wins (this is the "replace the free ATS check with the Fit check" step).

### Unchanged
The `/api/optimize` flow is untouched and remains the destination when the user taps **Optimize for this job**. `convert-session` continues to upgrade an anonymous Fit result into an account.

## iOS Changes

### New Files
| File | Purpose |
|------|---------|
| `Features/V2/Fit/FitCheckView.swift` | Paste-JD + Check Fit entry screen (front door of Tailor) |
| `Features/V2/Fit/FitVerdictView.swift` | Verdict screen: band, score ring, 3 gaps, missing keywords, CTAs |
| `Features/V2/Fit/FitCheckViewModel.swift` | `@Observable @MainActor`; calls fit-check service, holds verdict state |
| `Models/FitVerdict.swift` | `FitVerdict` model + `FitBand` enum; flexible Codable decoder (snake/camel) |
| `Core/API/FitCheckService.swift` | Calls `POST /api/public/ats-check` (anonymous-capable), decodes the new `fit` block, injectable for tests/previews |
| `ResumeBuilder IOS APPTests/FitCheckViewModelTests.swift` | Verdict mapping + error-path tests |

### Modified Files
| File | Change |
|------|--------|
| Tailor entry (`TailorView` / `HomeView` optimize CTA) | Route paste-JD into `FitCheckView` first; "Optimize" becomes the verdict-screen CTA, not the first action |
| `ResumeDiagnosisMapper` / `Models/ResumeDiagnosis.swift` | Reuse `ResumeGap` / `ResumeKeyword` types for fit gaps/keywords (no duplication) |
| `AnalyticsEvent` (analytics contract) | Add the 4 `fit_check_*` events + contract tests (per existing 16-event pattern) |
| `Localizable.xcstrings` | New EN + HE strings, RTL-safe |
| `RuntimeFeatures` / `BackendConfig` | `isFitCheckEnabled` flag so the step can ship dark and be toggled |

### Navigation
New front door for the tailor journey: **paste JD → FitCheckView → FitVerdictView**. From the verdict: **Optimize for this job** pushes into the existing diagnosis → Improve flow (unchanged); **Skip** returns to the entry with the JD optionally savable for later. All new screens live in `Features/V2/`. Dark mode only, matching the app.

## Development Stories
0. Story 0 **(web repo `new-ResumeBuilder-ai-`)**: Extend `/api/public/ats-check` `formatResponse` with the additive `fit` block (verdict band + topGaps + missingKeywords derived from `scoreResume`/`extractJob`); render the verdict on the existing free-ATS-check web page — **M**
1. Story 1 (iOS): `FitVerdict` model + `FitCheckService` (decodes `fit` from `/api/public/ats-check`) + flexible decoder + unit tests — **S/M**
2. Story 2 (iOS): `FitCheckView` (paste + Check Fit) and `FitVerdictView` (band, gaps, keywords, CTAs) behind `isFitCheckEnabled` — **M**
3. Story 3 (iOS): Wire Tailor/Home entry to route through Fit-check; verdict CTA into existing optimize flow — **M**
4. Story 4 (iOS): Analytics events + contract tests; EN/HE localization + RTL pass — **S/M**

> Story 0 lands first (web) so the new fields exist. iOS Stories 1–3 can be built against a mocked service in parallel, then pointed at the live endpoint once Story 0 ships.

## Open Questions
1. Verdict thresholds + server ownership of the band (recommend server-owned: ≥75 / 50–74 / <50; client renders `fit.verdict` as sent).
2. iOS resume input: the current free check takes a **resume PDF upload**. In-app the resume is already on file — confirm whether the mirrored iOS path passes the stored resume (avoid re-upload) or keeps the upload model for v1. (Affects whether a small server change is needed to accept a stored `resume_id` for authed sessions.)
3. JD minimum: web enforces ≥100 words — keep the same minimum on the iOS paste flow? (Recommend yes, parity.)
4. Does "Skip / save for later" persist anywhere, or is it ephemeral in v1? (Recommend ephemeral in v1; persistence belongs with the Wedge 3 outcome loop.)

## Out of Scope
- Share-extension "forward a job" inbox (fast-follow).
- Job discovery / aggregation / a job board.
- Outcome tracking and the response-rate loop (Wedge 3, separate spec).
- "Which of my resumes fits best" multi-resume comparison.
