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
