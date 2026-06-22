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

### New Endpoints
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/fit-check` | Lightweight match of active resume vs a pasted JD. Returns match score, verdict band, top gaps, missing keywords. Does NOT create an optimization or consume a credit. |

> Backend decision (Open Question 1). **Recommended:** a dedicated cheap endpoint that runs only the scoring/keyword pass of the existing diagnosis pipeline (no full rewrite). **Fallback if backend can't ship in time:** call the existing optimize path and map its diagnosis, gated behind a feature flag — but this costs latency + credit and is explicitly a stopgap, not the target.

### Request / Response Shapes
```json
// POST /api/v1/fit-check  (request)
{
  "resume_id": "uuid-or-null-for-active",
  "jd_text": "pasted job description text"
}
```
```json
// response
{
  "match_score": 68,
  "verdict": "stretch",            // "strong" | "stretch" | "skip"
  "top_gaps": [
    { "title": "No cloud infra experience", "detail": "JD requires AWS; resume shows none" }
  ],
  "missing_keywords": [
    { "keyword": "Terraform", "importance": "high" }
  ],
  "score_note": "Estimated fit vs this job, not a hiring guarantee."
}
```
Verdict bands (tunable server-side; client must not hardcode if the server sends `verdict`): Strong ≥ 75, Stretch 50–74, Skip < 50.

### Modified Endpoints
None required for v1. The existing `/api/optimize` flow is unchanged and is the destination when the user taps **Optimize for this job**.

## iOS Changes

### New Files
| File | Purpose |
|------|---------|
| `Features/V2/Fit/FitCheckView.swift` | Paste-JD + Check Fit entry screen (front door of Tailor) |
| `Features/V2/Fit/FitVerdictView.swift` | Verdict screen: band, score ring, 3 gaps, missing keywords, CTAs |
| `Features/V2/Fit/FitCheckViewModel.swift` | `@Observable @MainActor`; calls fit-check service, holds verdict state |
| `Models/FitVerdict.swift` | `FitVerdict` model + `FitBand` enum; flexible Codable decoder (snake/camel) |
| `Core/API/FitCheckService.swift` | `POST /api/v1/fit-check`, injectable for tests/previews |
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
1. Story 1: `FitVerdict` model + `FitCheckService` + flexible decoder + unit tests — **S/M**
2. Story 2: `FitCheckView` (paste + Check Fit) and `FitVerdictView` (band, gaps, keywords, CTAs) behind `isFitCheckEnabled` — **M**
3. Story 3: Wire Tailor/Home entry to route through Fit-check; verdict CTA into existing optimize flow — **M**
4. Story 4: Analytics events + contract tests; EN/HE localization + RTL pass — **S/M**

> Stories are ordered so each ends on a green build. Story 1 is backend-independent (mockable). Stories 2–3 can demo against a mocked service until `/api/v1/fit-check` is live.

## Open Questions
1. **Backend:** dedicated `/api/v1/fit-check` vs reuse optimize path? (Recommend dedicated; blocker to resolve first.)
2. Anonymous/no-account fit-check like the public ATS check? (Recommend yes — best activation hook; needs a public variant of the endpoint.)
3. Exact verdict thresholds and whether the server owns them (recommend server-owned; client renders `verdict` as sent).
4. Does "Skip / save for later" persist anywhere, or is it ephemeral in v1? (Recommend ephemeral in v1; persistence belongs with the Wedge 3 outcome loop.)

## Out of Scope
- Share-extension "forward a job" inbox (fast-follow).
- Job discovery / aggregation / a job board.
- Outcome tracking and the response-rate loop (Wedge 3, separate spec).
- "Which of my resumes fits best" multi-resume comparison.
