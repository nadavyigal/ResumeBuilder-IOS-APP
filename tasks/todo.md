# Story: Fit-First Triage Story 1 — FitCheckService (2026-06-23)

Decision: implement only the iOS service/model story for the Fit-First Triage wedge. Verdict bands are server-owned (>=75 Strong / 50-74 Stretch / <50 Skip as fallback only), resume input stays PDF re-upload, and the endpoint is the existing `POST /api/public/ats-check`.

## Files
- [x] `ResumeBuilder IOS APP/Core/API/Models/FitVerdict.swift` — create `FitVerdict` + `FitBand` with flexible Codable decoding, score clamping, and existing `ResumeGap`/`ResumeKeyword` reuse
- [x] `ResumeBuilder IOS APP/Core/API/FitCheckService.swift` — create protocol, live implementation on `APIClient.runPublicATSCheck`, and injectable mock
- [x] `ResumeBuilder IOS APP/Core/API/Models/DomainModels.swift` — add additive optional `fit` decode to `ATSScoreResult`
- [x] `ResumeBuilder IOS APP/Core/API/RuntimeServices.swift` — expose the live `FitCheckService`
- [x] `ResumeBuilder IOS APPTests/FitCheckServiceTests.swift` — cover payload shapes, band fallback derivation, service/mock behavior, and error mapping
- [x] `ResumeBuilder IOS APP.xcodeproj/project.pbxproj` — add the new test file to the explicit test target
- [x] `tasks/progress.md`, `tasks/MEMORY.md`, `tasks/session-log.md` — update completion memory

## Checklist
- [x] Decode `fit.verdict` when present; derive band from `score.overall` only when verdict is absent
- [x] Decode snake_case and camelCase response keys
- [x] Clamp scores to `0...100`
- [x] Follow the safe Codable pattern: decode candidates into locals before `??`
- [x] Reuse `ResumeGap` and `ResumeKeyword`; do not duplicate gap/keyword model types
- [x] Reuse `APIEndpoint.publicATSCheck`/`APIClient`; do not hardcode endpoint URLs
- [x] Keep Story 1 service-only; no UI screens and no optimize/diagnosis behavior changes

## Validation
- [x] Xcode build succeeds
- [x] Focused `FitCheckServiceTests` run with a non-zero executed test count
- [x] Live `/api/public/ats-check` response decode attempted against reachable Story-0 endpoint; production responded with the existing ATS payload but no additive `fit` block, so the single remaining gate is: deploy Story 0 with `fit`, then rerun the same live call and confirm `FitVerdict` decoding.

---

# Story: Resumely ATS Claim Defensibility (2026-06-20)

Decision: the displayed score is a self-defined "Resumely Match Score", NOT an external ATS vendor's score. ATS copy must be process-descriptive, never outcome-guaranteeing. Copy/labels only — no scoring logic changes.

Canonical strings:
- Score name (room): "Resumely Match Score" / he "ציון ההתאמה של Resumely"
- Score name (constrained): "Match Score" / he "ציון התאמה"
- Explainer: "Based on formatting + keyword match vs the job you paste. Not affiliated with any ATS vendor." / he "מבוסס על עיצוב והתאמת מילות מפתח למשרה שהדבקת. לא מזוהה עם אף ספק ATS."

## Tasks
- [x] ScoreResultView.swift — "ATS Score" → "Resumely Match Score" + explainer microcopy
- [x] OptimizedResumeView.swift — score-card explainer + footer "ATS score" → "Match Score"
- [x] ExpertOutputViews.swift — "ATS Score" → "Match Score"
- [x] ImproveView.swift — metric card "ATS Score" → "Match Score"
- [x] ApplicationDetailView.swift — LabeledContent "ATS score" → "Match Score"
- [x] ApplicationCompareView.swift — ring caption "ATS"→"Match", a11y "ATS score …" → "Match Score …"
- [x] HomeActivationState.swift — "Your free ATS score is in" → "Your free Resumely Match Score is in"
- [x] MarketingScreenshotView.swift — "ATS score" label → "Match Score"; "ATS scores every section" → "Scores every section"; "Templates that pass ATS…" → "ATS-friendly templates…"
- [x] MetricCard.swift — #Preview label aligned to "Match Score"
- [x] OptimizedResumeViewModel.swift — error "ATS score" → "Match Score"
- [x] LinkedInShareComposer.swift — EN + HE: frame number as Resumely match score
- [x] Localizable.xcstrings — renamed keys + Hebrew values; added explainer + "Match" keys
- [x] docs/app-store/he-metadata.md — fixed "ATS score שלך", "ציון ATS", interview-outcome promo line
- [x] Build succeeds (iPhone 17 Pro simulator, Debug) — ** BUILD SUCCEEDED **
- [x] Kept "ATS" only in descriptive contexts (ATS check / ATS insights / ATS match / ATS-friendly / template ATS attribute)

## Deliberately kept (descriptive/feature ATS usage, allowed by decision)
- "Ready for a free ATS check" (HomeActivationState) — a check, not a possessive score
- "ATS insights" / "Improve ATS" / "ATS match" / "ATS-friendly" — process/feature language
- OptimizationDesignSheet template "ATS" badge — template's ATS-friendliness attribute, not user's resume score
- ResumeDiagnosis "More aligned, not guaranteed to pass any ATS." — explicit disclaimer (good)
- DomainModels DecodingError debug strings — developer-only, never user-facing

## Flagged (generated artifacts, not source) — screenshot manifests still say "Templates that pass ATS":
- dist/app-store-screenshots/rb-aso-002/upload-manifest.md
- dist/app-store-screenshots/app-store-v1/upload-manifest.md
