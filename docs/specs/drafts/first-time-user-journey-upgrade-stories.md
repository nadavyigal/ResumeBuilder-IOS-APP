# Development Stories — Trustworthy First-Time Journey Upgrade

**Feature:** Trustworthy First-Time Journey Upgrade
**Spec:** `docs/specs/drafts/first-time-user-journey-upgrade-spec.md`
**Date:** 2026-07-13
**Status:** Release A approved — 2026-07-14; Releases B and C remain out of scope

Every story must leave the app buildable. New production types must be `Sendable` or `@MainActor`, new screens belong in `Features/V2/`, and no new package is permitted.

## Release A — Trustworthy completion

### Story 1 — Golden-path regression harness

**Size:** M (2–3h)
**Objective:** Encode the audit fixture and core state transitions before changing navigation.

**Files:** Create `FirstSessionJourneyTests.swift`; extend existing Tailor, review, AppState, and optimized-view mocks/tests.

**Acceptance criteria:**

- [ ] Synthetic résumé/job fixture covers guest check → auth → review → apply → preview state.
- [ ] A regression test demonstrates the current competing-navigation failure or its state preconditions.
- [ ] Tests assert one optimization ID propagates to every tab wrapper.
- [ ] No live network calls.

### Story 2 — Deterministic Apply-to-preview route

**Size:** M (2–3h)
**Prerequisite:** Story 1
**Objective:** Replace competing Boolean destinations with one route and one success transition.

**Files:** Create `FirstSessionJourneyRoute.swift`; modify `HomeTabView.swift`, `OptimizationReviewView.swift`, and `MainTabViewV2.swift`.

**Acceptance criteria:**

- [ ] Apply success cannot leave a blank review screen.
- [ ] Optimization ID persists before route/tab mutation.
- [ ] One optimized preview is visible after Apply.
- [ ] Apply failure remains on review with retry and no false success.
- [ ] Focused tests and simulator smoke pass.

### Story 3 — Reconcile one optimization source of truth

**Size:** M (2–3h)
**Prerequisite:** Story 2
**Objective:** Restore missing local completion state from authenticated backend history and synchronize all tabs.

**Files:** Modify `AppState.swift`, `MainTabViewV2.swift`, `OptimizedResumeTabView.swift`, `DesignTabView.swift`, `ExpertTabView.swift`, `ProfileView.swift`, and `LockedTabTeaser.swift`.

**Acceptance criteria:**

- [ ] Relaunch restores the latest valid optimization when local state is absent.
- [ ] Account and all tabs agree on the same ID and completion status.
- [ ] Recovery has loading, success, and actionable failure states.
- [ ] Stale/mock IDs are not treated as valid production completion.
- [ ] `optimization_state_recovered` is PII-safe.

### Story 4 — Shared job-input policy and friendly errors

**Size:** S–M (1–2h)
**Objective:** Prevent avoidable server validation failures on Home and Fit.

**Files:** Create `JobInputPolicy.swift`; modify `HomeTabView.swift`, `FitCheckViewModel.swift`, `TailorViewModel.swift`, and localized strings.

**Acceptance criteria:**

- [ ] URL and pasted text use explicit, shared validation rules.
- [ ] Live word count and requirement appear before submission.
- [ ] Invalid pasted text cannot trigger the API call.
- [ ] Expected input errors do not display HTTP terminology.
- [ ] Unit tests cover whitespace, URL-only, boundary, and valid cases.

### Story 5 — Recommendation presentation safety gate

**Size:** M (2–3h)
**Objective:** Stop clearly unsafe generated output from reaching Apply even before backend metadata ships.

**Files:** Create `RecommendationSafetyPolicy.swift` and tests; modify `OptimizationReviewView.swift`, diagnosis rendering, and analytics.

**Acceptance criteria:**

- [ ] `{placeholder}` patterns are suppressed and tracked.
- [ ] Non-positive projected deltas show a blocking warning; Apply is not the default action.
- [ ] Title, company, date, degree, contact, and metric changes default off.
- [ ] A user can still view original content and understand why a group was blocked.
- [ ] Audit fixtures for title inflation, removed date, and 53→52 all pass.

### Story 6 — Preview, save, export, and relaunch recovery

**Size:** L (3–4h)
**Prerequisites:** Stories 2–5
**Objective:** Close Release A with the real user deliverable.

**Files:** Modify `OptimizedResumeView.swift`, `OptimizedResumeViewModel.swift`, `SavedResumePickerSheet.swift`, relevant export/save services, and tests.

**Acceptance criteria:**

- [ ] Preview visibly confirms applied changes.
- [ ] Save state is attached to preview, not a dismissed route.
- [ ] Save can retry without hiding output.
- [ ] Export/share produces a valid text-layer PDF through backend or local fallback.
- [ ] Relaunch recovers preview, Account history, and saved résumé consistently.
- [ ] Simulator and physical-device smoke evidence is captured.

## Release B — Continuous, evidence-backed journey

### Story 7 — Preserve guest context through authentication

**Size:** M (2–3h)
**Prerequisite:** Release A
**Objective:** Continue from guest diagnosis directly into authenticated review preparation.

**Files:** Modify `HomeTabView.swift`, `OnboardingViewModel`, `TailorViewModel.swift`, `AppState.swift`, and tests.

**Acceptance criteria:**

- [ ] Signup preserves résumé selection, job input, and guest diagnosis.
- [ ] No post-signup Analyze button is required for unchanged inputs.
- [ ] Auth cancellation returns to the intact guest diagnosis.
- [ ] Changed inputs invalidate only dependent results.

### Story 8 — Merge Fit into the diagnosis continuation

**Size:** M (2–3h)
**Prerequisite:** Story 7
**Objective:** Remove the redundant Check Fit confirmation while retaining fit guidance.

**Files:** Modify `HomeTabView.swift`, `FitCheckView.swift`, `FitCheckViewModel.swift`, diagnosis models/views, and tests.

**Acceptance criteria:**

- [ ] Fit runs automatically or appears inside diagnosis for unchanged input.
- [ ] The same job is not displayed as a second confirmation form.
- [ ] User can edit the target job before optimization.
- [ ] Fit failure degrades gracefully without losing the guest result.

### Story 9 — Evidence-backed review with Accept and Skip

**Size:** L (3–4h)
**Prerequisite:** Backend additive metadata or agreed fallback
**Objective:** Make every applied change deliberate and traceable. Edit-and-resubmit requires a separate backend contract work packet.

**Files:** Modify review models, decoders, `OptimizationReviewView.swift`, and tests.

**Acceptance criteria:**

- [ ] Each group shows job evidence and résumé evidence when available.
- [ ] User can Accept or Skip.
- [ ] Factual changes require explicit confirmation and never default on.
- [ ] No UI implies edited recommendation text can be submitted through the current apply contract.
- [ ] Analytics records decisions without content.

### Story 10 — Canonical activation and failure instrumentation

**Size:** M (2–3h)
**Prerequisites:** Stories 6–9
**Objective:** Measure user-consumed value and make remaining abandonment diagnosable.

**Files:** Modify `AnalyticsService.swift` and event call sites; extend analytics tests.

**Acceptance criteria:**

- [ ] `optimized_preview_rendered` fires only after visible content renders.
- [ ] Apply, validation, recovery, recommendation, save, and export lifecycle events exist.
- [ ] Local file selection and server upload completion are semantically distinct.
- [ ] Events include stable non-content correlation IDs and internal-tester properties.
- [ ] A documented funnel query can reproduce the new activation path.

## Release C — Reach and retention polish

### Story 11 — Touched-screen localization and accessibility pass

**Size:** M (2–3h)
**Prerequisite:** Release B UI stable
**Objective:** Remove mixed-language output and verify inclusive interaction on the upgraded path.

**Files:** Modify touched SwiftUI views, `Localizable.xcstrings`, and accessibility/UI tests where feasible.

**Acceptance criteria:**

- [ ] No unintended English fragments remain in Hebrew on touched screens.
- [ ] Signup fields retain visible labels outside placeholders.
- [ ] VoiceOver order/names, Dynamic Type, Reduce Motion, keyboard avoidance, and contrast pass a documented check.
- [ ] RTL preview/export remains separately gated until physical-device PDF QA passes.

### Story 12 — Optimize another job retention loop

**Size:** M (2–3h)
**Prerequisite:** Reliable saved/recovered résumé
**Objective:** Turn the completed first optimization into a clear second-job action.

**Files:** Modify `OptimizedResumeView.swift`, `HomeTabView.swift`, `AppState.swift`, and analytics tests.

**Acceptance criteria:**

- [ ] “Optimize for another job” reuses the saved résumé and clears only job-dependent state.
- [ ] Prior optimized output remains recoverable.
- [ ] User lands directly at job input with clear context.
- [ ] `second_job_started` fires without content properties.

### Story 13 — Release-candidate journey audit

**Size:** M (2–3h)
**Prerequisites:** Stories 1–12 selected for the release
**Objective:** Re-run the original evidence journey and publish a pass/fail delta.

**Files:** New QA report/evidence only unless defects are found; update task records.

**Acceptance criteria:**

- [ ] Clean simulator run covers the same 20 audit checkpoints plus exported PDF and return loop.
- [ ] Debug and Release builds succeed; relevant tests pass.
- [ ] Physical iPhone validates preview, export/share, relaunch, Hebrew, and file picker.
- [ ] No critical/high trust or completion defect remains open.
- [ ] Monetization decision is made only from the verified journey and clean cohort data.

## Recommended Sequence and Estimate

| Release | Stories | Focused effort | Decision gate |
|---|---|---:|---|
| A | 1–6 | 12–18h | Core output is trustworthy and recoverable |
| B | 7–10 | 9–13h plus backend dependency | One continuous, evidence-backed path is measurable |
| C | 11–13 | 6–9h | Accessibility, retention, and release audit pass |

Calendar duration depends on backend evidence/edit support and physical-device availability. Do not parallelize stories that touch `HomeTabView` or optimization navigation unless ownership is explicit; those files are the highest merge- and regression-risk surfaces.
