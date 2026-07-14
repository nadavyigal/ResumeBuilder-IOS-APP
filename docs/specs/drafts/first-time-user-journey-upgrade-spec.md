# Feature Spec — Trustworthy First-Time Journey Upgrade

**Date:** 2026-07-13
**Status:** Draft — do not implement until approved
**Brief:** `docs/specs/drafts/first-time-user-journey-upgrade-brief.md`
**Story plan:** `docs/specs/drafts/first-time-user-journey-upgrade-stories.md`
**Audit evidence:** `docs/audits/first-time-user-journey-audit.md`

## Objective

We are upgrading Resumely’s first-time journey so that a guest who supplies a résumé and target job can move continuously through diagnosis, signup, safe review, optimized preview, save, and export without repeated work, contradictory state, or unverified factual changes.

## User Story

As a first-time job seeker, I want Resumely to remember my work and show why each suggested change is safe and relevant so that I can export a trustworthy job-specific résumé from my iPhone.

## Product Principles

1. **Value before identity:** preserve the guest diagnosis before signup.
2. **One intent, one action:** do not make the user analyze or confirm the same job twice.
3. **Facts are protected:** titles, employers, dates, degrees, and metrics require explicit approval when changed.
4. **Evidence over authority:** every recommendation points to a job requirement and résumé passage.
5. **Completion means consumption:** backend completion is not activation until the optimized preview renders.
6. **One source of truth:** every tab derives completion from the same reconciled optimization state.

## Target Journey

| Stage | Primary user action | Product responsibility | Exit condition |
|---|---|---|---|
| Home | Choose résumé | Confirm supported file and preserve local selection | Résumé ready |
| Job | Add URL or paste description | Validate inline using one shared rule | Job ready |
| Guest diagnosis | Run free check | Show limited, evidence-backed value | Diagnosis visible |
| Account | Create/sign in | Preserve diagnosis and continue automatically | Auth restored without reset |
| Review | Review fixes | Show evidence, protect facts, allow edit/skip | At least one deliberate choice |
| Apply | Apply approved changes | Persist optimization and route deterministically | Optimization ID reconciled |
| Preview | Inspect optimized résumé | Render actual output and show save/export status | `optimized_preview_rendered` |
| Export | Preview/share PDF | Produce valid, recoverable document | Export result shown |
| Return | Reuse résumé | Recover prior output and accept a new target job | Second-job flow starts |

## Acceptance Criteria

### Completion and recovery

- [ ] Applying review changes opens one optimized-preview destination; no intermediate blank page is possible.
- [ ] Apply shows a clear in-progress state, success transition, and actionable failure/retry state.
- [ ] `latestOptimizationId` is persisted before navigation and reconciled against authenticated optimization history after session restore.
- [ ] Home, Optimized, Design, Expert, and Account show the same completion state during the same render cycle.
- [ ] If local state is absent but backend history contains a completed optimization, the app restores it and explains that recovery once.
- [ ] Relaunching after preview restores the same optimized résumé.

### Input clarity

- [ ] URL input and pasted-description input have distinct readiness rules.
- [ ] Pasted job descriptions show a live word count and the requirement before submission.
- [ ] The submit CTA cannot send text the API will reject for length.
- [ ] Validation uses friendly inline language and never prefixes expected input errors with “Server error (400).”
- [ ] Home, guest ATS, and Fit use one shared validation policy.

### Recommendation safety and trust

- [ ] Raw template placeholders are blocked from display and tracked as content-quality failures.
- [ ] An after-score less than or equal to the before-score cannot be presented as an improvement without an explicit warning and disabled default Apply.
- [ ] Changes touching title, company, dates, degree, location, contact data, or numerical achievements are classified as factual-field changes.
- [ ] Factual-field changes default to unselected and require explicit confirmation.
- [ ] Each recommendation exposes the target job evidence and, where applicable, source résumé evidence.
- [ ] Users can Accept, Edit, or Skip each recommendation; edits are reflected in the applied payload or a documented backend-compatible override.
- [ ] Duplicate score labels are removed and the metric is consistently named Resumely Match Score/estimate.

### Continuity

- [ ] Successful signup closes the auth sheet and returns to the preserved guest diagnosis.
- [ ] The existing résumé, job, and public analysis are reused; the user is not asked to tap Analyze again.
- [ ] Fit appears as part of the preserved diagnosis or runs automatically; no second “Check Fit” confirmation is required for unchanged inputs.
- [ ] Changing the résumé or job invalidates only the dependent analysis, with clear feedback.

### Preview, save, and export

- [ ] The first optimized preview visibly confirms that changes were applied.
- [ ] Save status appears on the preview and is independent of navigation timing.
- [ ] A save failure does not hide the optimized output and can be retried.
- [ ] Preview & Export PDF completes through the backend or documented local fallback and yields a valid text-layer PDF.
- [ ] The saved-résumé picker and Account history both expose the completed item after relaunch.

### Measurement

- [ ] `optimization_completed` remains a backend/process milestone.
- [ ] `optimized_preview_rendered` fires only after visible preview content renders successfully.
- [ ] Apply, validation, recovery, recommendation decision, save, and export failures include non-content error categories.
- [ ] Upload event naming distinguishes local file selection from server upload completion.
- [ ] Internal/founder/QA users remain separable from production cohorts.

### Quality

- [ ] No production code uses `ObservableObject`/`@Published`; new state is `@Observable @MainActor` and shared values are `Sendable`.
- [ ] All new screens live under `Features/V2/`.
- [ ] No API URL is hardcoded and no new package is added.
- [ ] Debug and Release builds succeed; relevant tests pass.
- [ ] Simulator golden-path smoke passes on iPhone 17 and the smallest available supported simulator.
- [ ] Physical-iPhone preview/export/relaunch smoke passes before release.
- [ ] English, Hebrew RTL, VoiceOver, Dynamic Type, keyboard, and Reduce Motion checks pass on touched screens.

## API Changes

### New Endpoints

No new endpoint is required for the P0 completion repair if authenticated optimization history and optimization detail remain available. Prefer extending existing contracts over adding a parallel first-session API.

### Modified Endpoints

| Endpoint | Proposed change |
|---|---|
| `POST /api/public/ats-check` | Return normalized validation metadata/error categories and suppress unresolved placeholders before response. |
| `POST /api/optimize` and optimization-review creation | Preserve correlation IDs and return a stable review/optimization state for continuity. |
| `GET /api/v1/optimization-reviews/{id}` | Add per-group evidence, confidence, factual-field classification, and quality warnings. |
| Apply optimization review endpoint | Accept optional user-edited text overrides per approved group, or expose a documented follow-up edit endpoint. |
| `GET /api/v1/optimizations` / detail | Remain the recovery source for latest completed optimization and preview data. |
| Saved résumé endpoint | Return idempotent save status for an optimization; repeated save must not create duplicate user-visible items. |

### Proposed Additive Response Shape

```json
{
  "validation": {
    "job_description_min_words": 100
  },
  "quality": {
    "status": "pass",
    "warnings": []
  },
  "grouped_changes": [
    {
      "id": "summary-1",
      "before": "Original text",
      "after": "Suggested text",
      "job_evidence": ["Exact requirement from the job"],
      "resume_evidence": ["Exact source from the resume"],
      "confidence": "high",
      "touches_factual_field": false,
      "factual_fields": [],
      "projected_score_delta": 4
    }
  ]
}
```

All additions should be optional during rollout so the current client decoder remains compatible. The iOS safety guard must still reject unresolved placeholders and fact-risky defaults when metadata is absent.

## iOS Changes

### New Files

| File | Purpose |
|---|---|
| `Features/V2/Home/FirstSessionJourneyRoute.swift` | `Hashable`, `Sendable` destination model for one deterministic navigation path. |
| `Features/V2/Home/JobInputPolicy.swift` | Shared URL/text readiness and word-count policy used by Home and Fit. |
| `Features/V2/History/RecommendationSafetyPolicy.swift` | Pure, testable rules for placeholder, regression, and factual-field safety. |
| `Features/V2/History/RecommendationEditSheet.swift` | User edit surface for one generated change. |
| `ResumeBuilder IOS APPTests/FirstSessionJourneyTests.swift` | Continuity, routing, reconciliation, and activation regression coverage. |
| `ResumeBuilder IOS APPTests/RecommendationSafetyPolicyTests.swift` | Content-safety fixtures and regression cases. |

### Modified Files

| File | Change |
|---|---|
| `Features/V2/Home/HomeTabView.swift` | Replace competing Boolean destinations with one route; preserve guest result through auth; remove repeated actions; inline job validation. |
| `App/AppState.swift` | Reconcile/persist latest optimization and expose one completion state. |
| `App/MainTabViewV2.swift` | Synchronize mounted tabs from reconciled state and support deterministic preview switching. |
| `Features/Tailor/TailorViewModel.swift` | Preserve first-session context, normalize errors, and separate file-selected/uploaded analytics semantics. |
| `Features/V2/Fit/FitCheckViewModel.swift` | Use shared job policy and support automatic fit result for unchanged input. |
| `Features/Score/ScoreResultView.swift` | Remove duplicate score rendering and normalize metric naming. |
| `Features/V2/History/OptimizationReviewView.swift` | Evidence, safety warnings, factual defaults, edit/skip/accept, and direct preview transition. |
| `Features/V2/Improve/OptimizedResumeTabView.swift` | Loading/recovery state instead of false locked state; render activation tracking. |
| `Features/V2/Improve/OptimizedResumeView.swift` | Applied confirmation, save state, export recovery, and another-job CTA. |
| `Features/V2/Design/DesignTabView.swift` | Derive lock/progress from reconciled optimization state. |
| `Features/V2/Expert/ExpertTabView.swift` | Derive lock/progress from reconciled optimization state. |
| `Features/V2/Home/LockedTabTeaser.swift` | Truthful CTA and recover/latest behavior. |
| `Features/Profile/ProfileView.swift` | Reuse shared optimization state rather than an independent source of truth. |
| `Features/Tailor/SavedResumePickerSheet.swift` | Reflect save completion and provide retry/recovery. |
| `Core/Analytics/AnalyticsService.swift` | Add preview-rendered, validation, review-decision, apply, recovery, save, and continuation events. |
| `Resources/Localizable.xcstrings` | Complete EN/HE copy for touched surfaces and remove mixed-language fragments. |

### Navigation

Use one journey destination instead of `shouldNavigate`, `showDiagnosis`, and post-callback tab switching competing in the same transaction. The Apply success sequence is:

1. Apply returns or recovers a valid optimization ID.
2. Persist the ID and related job context in `AppState`.
3. Reconcile the optimization detail needed for preview.
4. Replace the review route with `.optimizedPreview(id:)` or switch once to the Optimized tab.
5. Track `optimized_preview_rendered` only after the preview’s visible content is ready.
6. Present save status inside the preview; do not attach it to the dismissed Home destination.

## Analytics Contract

| Event | Fires when |
|---|---|
| `free_ats_started` / `free_ats_failed` | Public analysis begins/fails |
| `job_input_validation_shown` | A shared input rule blocks continuation |
| `signup_gate_viewed` / `signup_started` / `signup_failed` | Guest-to-auth boundary is entered |
| `continuation_reprompt_viewed` | A legacy/recovery prompt asks for repeated intent; target is zero |
| `recommendation_viewed` | A recommendation becomes visible |
| `recommendation_included` / `edited` / `skipped` | User makes a deliberate per-change choice |
| `recommendation_blocked` | Safety policy suppresses unsafe output |
| `optimization_apply_started` / `apply_failed` | Apply begins/fails |
| `optimization_state_recovered` | Backend history restores missing local state |
| `optimized_preview_rendered` | Visible optimized content renders successfully |
| `saved_resume_prompt_viewed` / `save_success` / `save_failed` | Preview-level save lifecycle |
| `locked_tab_viewed` | A locked tab is shown, with reconciled-state properties |
| `second_job_started` | User reuses the résumé for a new target job |

Never attach résumé text, job-description text, email, or generated content to analytics events.

## Release Plan

### Release A — Trustworthy completion (P0)

- Golden-path regression harness.
- Deterministic Apply → preview navigation.
- Reconciled optimization state across all tabs.
- Shared input validation.
- Placeholder/regression/factual safety guard.
- Preview/save/export/relaunch recovery verification.

**Exit gate:** the 20-step audit is rerun from a clean simulator and the core journey passes through a valid exported PDF with no critical or high-severity trust defect.

### Release B — Continuous, evidence-backed journey (P1)

- Guest-to-auth continuity and automatic fit reuse.
- Evidence-backed recommendations with edit/skip/accept.
- Preview-level save state.
- Activation and failure instrumentation.

**Exit gate:** one user confirmation from signup to review, all recommendation fixtures explain their evidence, and `optimized_preview_rendered` is measurable.

### Release C — Reach and retention polish (P2)

- Hebrew/accessibility cleanup on touched screens.
- “Optimize another job” reuse loop.
- Separate discovery/spec for paste-text résumé input if production evidence supports it.
- Monetization remains disabled until a clean cohort meets completion and trust gates.

## Development Stories

See `docs/specs/drafts/first-time-user-journey-upgrade-stories.md` for 13 ordered stories, each sized for one focused session and independently verifiable.

## Open Questions

1. Backend ownership and rollout date for evidence/factual metadata.
2. Whether edited recommendation text can be submitted in the existing apply request.
3. Whether the existing saved-résumé service is enabled in the production runtime targeted by this upgrade.
4. Smallest available supported simulator for release QA if iPhone SE is unavailable.

## Out of Scope

- Monetization enablement or StoreKit QA.
- Paid acquisition, ASO changes, or new marketing claims.
- Full manual résumé creation.
- Broad visual rebranding.
- New push-notification flows.
