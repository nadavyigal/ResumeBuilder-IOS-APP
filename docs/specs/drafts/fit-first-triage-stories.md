# Dev Stories — Fit-First Triage

**Feature:** Fit-First Triage
**Spec:** `docs/specs/drafts/fit-first-triage-spec.md`
**Date:** 2026-06-22
**Status:** Pending (awaiting approval + Open Question 1 backend decision)

> Ordered so each story ends on a green build and is independently testable. Stories 1–3 work against a mocked `FitCheckService` until `/api/v1/fit-check` is live, so iOS is not blocked on backend.

---

## Story 1 — Fit verdict model + service + decoder
**Size:** M · **Prerequisites:** none (mockable)

### Files to Change
| File | Action | Change |
|------|--------|--------|
| `Models/FitVerdict.swift` | Create | `FitVerdict` struct + `FitBand` enum (`strong/stretch/skip`); flexible Codable decoder (snake + camel), score clamping, reuse `ResumeGap`/`ResumeKeyword` |
| `Core/API/FitCheckService.swift` | Create | Protocol + live impl `POST /api/v1/fit-check` via `APIClient`/`Endpoint`; injectable mock |
| `ResumeBuilder IOS APPTests/FitCheckViewModelTests.swift` | Create | Decode across payload shapes; band derivation; error mapping. Add file to the Xcode test target in `project.pbxproj` (per 2026-06-12 lesson) |

### Acceptance Criteria
- [ ] Decodes server `verdict` when present; derives band from `match_score` only as fallback.
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
- [ ] Backend Open Question 1 resolved before Story 3 ships against live data
