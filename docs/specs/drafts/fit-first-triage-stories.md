# Dev Stories — Fit-First Triage

**Feature:** Fit-First Triage
**Spec:** `docs/specs/drafts/fit-first-triage-spec.md`
**Date:** 2026-06-22
**Status:** Pending (awaiting founder approval + two decisions: verdict thresholds [before Story 0] and resume-input contract [before Story 1/3 live]). Endpoint approach is resolved — evolve `/api/public/ats-check`.

> Ordered so each story ends on a green build and is independently testable. **Story 0 (web) lands first** so the new `fit` fields exist; iOS Stories 1–3 work against a mocked `FitCheckService` in parallel, then point at the live endpoint.
> **Decision:** the Fit check is the evolved free ATS check `POST /api/public/ats-check` (web repo `new-ResumeBuilder-ai-`), mirrored to iOS — no new endpoint.

---

## Story 0 — Web: add the Fit layer to the free ATS check
**Repo:** `new-ResumeBuilder-ai-` · **Size:** M
**Prerequisites (resolve before starting):**
- [ ] **Verdict thresholds confirmed** — ≥75 strong / 50–74 stretch / <50 skip, or alternative approved by founder/backend lead (Brief Open Question 1). Locked before implementation to avoid mid-build debate; kept server-side so they stay tunable after ship.
- [ ] **Resume input contract decided** (Brief Open Question 2) — if iOS should pass a stored `resume_id` instead of re-uploading a PDF, that small server addition is part of this story.

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `src/app/api/public/ats-check/route.ts` | Modify | In `formatResponse`, add an **additive** `fit` block: `verdict` (band from `score.overall`), `scoreNote`, `topGaps`, `missingKeywords` (derived from `extractJob` `must_have` not matched in `resumeText`). Do not change existing `score`/`preview`/`quickWins`/`checksRemaining`. |
| Free ATS check web page (the page that calls `/api/public/ats-check`) | Modify | Render the verdict band (Strong/Stretch/Skip) above the existing score + quick wins |
| `tests/api/...ats-check...` | Modify/Create | Assert the `fit` block shape + that existing fields are unchanged |

### Acceptance Criteria
- [ ] Response includes `fit.{verdict, scoreNote, topGaps, missingKeywords}`; all pre-existing fields byte-for-byte unchanged in shape.
- [ ] Verdict band is server-owned and derived from `score.overall` (≥75/50–74/<50, easily tunable).
- [ ] `npm run lint && npx tsc --noEmit && npm run build` pass; rate-limiting on the route unchanged.
- [ ] No Supabase schema/RLS change required (reuses `anonymous_ats_scores`); if a column is added it goes through a reviewed migration (do not change RLS silently).

## Story 1 — iOS: Fit verdict model + service + decoder
**Size:** M · **Prerequisites:** Story 0 (or mock)
**Input contract (from Brief Open Question 2):** `FitCheckService` cannot be finalized until the resume-input decision is made — stored `resume_id`/session vs PDF re-upload. Build against the mock with the chosen shape; if undecided, default the mock to the existing PDF-upload contract and flag the swap as a follow-up.

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `Models/FitVerdict.swift` | Create | `FitVerdict` struct + `FitBand` enum (`strong/stretch/skip`); flexible Codable decoder (snake + camel), score clamping, reuse `ResumeGap`/`ResumeKeyword` |
| `Core/API/FitCheckService.swift` | Create | Protocol + live impl calling `POST /api/public/ats-check` (anonymous via `x-session-id`), decoding the `fit` block; injectable mock |
| `ResumeBuilder IOS APPTests/FitCheckViewModelTests.swift` | Create | Decode across payload shapes; band derivation; error mapping. Add file to the Xcode test target in `project.pbxproj` (per 2026-06-12 lesson) |

### Acceptance Criteria
- [ ] Decodes server `fit.verdict` when present; derives band from `score.overall` only as fallback.
- [ ] Decoder follows the safe pattern (decode candidates into locals before `??`) per the 2026-06-12 Codable lesson.
- [ ] Build succeeds; new tests run and pass (verify non-zero executed test count).

## Story 2 — Fit-check + verdict screens (flagged)
**Size:** M · **Prerequisites:** Story 1

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `Features/V2/Fit/FitCheckViewModel.swift` | Create | `@Observable @MainActor`; JD validation (empty/too-short before network), loading/verdict/error states, no-active-resume routing |
| `Features/V2/Fit/FitCheckView.swift` | Create | Paste JD + **Check Fit**; reuses the existing scanning/loading animation |
| `Features/V2/Fit/FitVerdictView.swift` | Create | Band header, score ring, 3 decisive gaps, missing keywords, **Optimize for this job** + **Skip** CTAs; process-descriptive copy + explainer |
| `RuntimeFeatures`/`BackendConfig` | Modify | Add `isFitCheckEnabled` (default off) |

### Acceptance Criteria
- [ ] Behind `isFitCheckEnabled`; off = zero change to current flow.
- [ ] Empty/short JD rejected inline before any call.
- [ ] Verdict renders Strong/Stretch/Skip with score, gaps, keywords; uses `@Observable`+`@MainActor` (not ObservableObject).
- [ ] Build + simulator smoke (iPhone 17 and iPhone SE) against mocked service.

## Story 3 — Wire entry + optimize handoff
**Size:** M · **Prerequisites:** Story 2

### Files to Change
| File | Action | Change |
|------|--------|--------|
| Tailor/`HomeView` optimize entry | Modify | When `isFitCheckEnabled`, route paste-JD → `FitCheckView` first; verdict's **Optimize for this job** enters the existing diagnosis → Improve flow with the same JD (no re-paste) |

### Acceptance Criteria
- [ ] Optimize is reached only via the verdict screen when the flag is on.
- [ ] JD carries through to optimize without re-entry; existing optimize/diagnosis behavior unchanged.
- [ ] Flag off = original direct-optimize path intact.
- [ ] Build + smoke pass.

## Story 4 — Analytics + localization
**Size:** S/M · **Prerequisites:** Story 3

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `AnalyticsEvent` + analytics service | Modify | Add `fit_check_started`, `fit_check_completed` (verdict, match_score), `fit_check_optimize_tapped`, `fit_check_skipped`; extend the contract test (16 → 20 events) |
| `Localizable.xcstrings` | Modify | EN + HE for all new strings; verify via `xcodebuild -exportLocalizations` (per 2026-06-17 lesson), RTL-safe |

### Acceptance Criteria
- [ ] All 4 events fire at the right points; contract tests pass.
- [ ] HE coverage verified through the xliff export, not grep.
- [ ] Build + full focused test suite green.

---

## Feature Definition of Done
- [ ] Xcode build: no errors
- [ ] All tests pass (confirm executed count, watch for the known teardown crash per 2026-06-16 lesson)
- [ ] Simulator smoke on iPhone 17 and iPhone SE; verdict + optimize handoff verified
- [ ] Claim-safety review: no outcome guarantees, no ATS-vendor claim (consistent with PR #70)
- [ ] `tasks/todo.md` + `tasks/progress.md` updated; lesson added if applicable
- [ ] Story 0 (web `fit` block) shipped before iOS Story 3 points at the live endpoint; both repos' branches pushed with open PRs

## Cross-repo coordination (mock → live handoff)
Lightweight checkpoint so iOS doesn't point at the live endpoint before the web side is ready:
- [ ] Story 0 merged to `new-ResumeBuilder-ai-` main and deployed
- [ ] `POST /api/public/ats-check` confirmed returning the `fit` block (correct shape) on the deployed environment
- [ ] iOS swaps `FitCheckService` from mock to live and spot-checks the decode before Story 3 is approved
- [ ] Only then: Story 3 enables `isFitCheckEnabled` against live data
