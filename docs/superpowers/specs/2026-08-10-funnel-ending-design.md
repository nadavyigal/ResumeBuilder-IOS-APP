# Design: give the funnel an ending

**Date:** 2026-08-10
**Status:** Approved, not yet planned
**Author:** Claude (Opus 5) with founder
**Repo:** ResumeBuilder IOS APP

## Problem

The top of the funnel converts and the bottom does not exist.

Measured 2026-08-10 in PostHog project 270848 (`$lib = resumely-ios-urlsession`, lifetime, project fingerprinted before reading):

| step | people |
|---|---|
| app_launched | 223 |
| guest_mode_started | 211 |
| fit_check_started → completed → optimize_tapped | 119 → 119 → 119 |
| optimization_completed | 104 |
| optimization_apply_succeeded | 80 |
| save_success | 93 |
| **optimized_viewed / export_cta_seen** | **9** |
| export_success | 5 |

The fit check converts 119 → 119 → 119 with zero loss. Then 90% of users vanish at a single step.

### Root cause

`export_cta_seen` and `optimized_viewed` are the *same* event, emitted from one function behind one guard, `OptimizedResumeView.trackOptimizedAndExportVisibilityIfNeeded()`:

```swift
guard isActive, let optimizationId = viewModel.optimizationIdentifier else { return }
```

`isActive` is `selectedTab == .optimized` (`MainTabViewV2.swift:24`). The tab is kept mounted at `opacity: 0`, so nothing on it fires or is seen until the user selects that tab.

Nothing in the post-optimize flow selects it. `TailorView.swift:199-231` routes apply → `OptimizationReviewDestination` → `ResumeDiagnosisView`, and the only path onward is the optional `onImprove` button at line 223. Users who take any other exit never reach the résumé.

The behavioral signature confirms it. The most common event *after* `optimization_completed` is `optimization_started` again, 95 people. People finished an optimization and immediately ran another one, which is what someone does when they do not believe they are done.

This was recorded as a test quirk in `tasks/lessons.md:184` on 2026-07-05 ("hidden tabs may never appear"). It was a product finding.

### What is not broken

Export itself works. 6 people have ever started an export and 6 completed it; one `export_failed` event exists in the app's lifetime. The ending is unreachable, not defective.

## Goals

1. Every user who applies an optimization lands on their finished résumé.
2. Guests can export without an account, capped at 5 per calendar month.
3. Registration is pitched as an unlock at the moment of value, not as a toll before it.
4. The fit-check flow is not touched and its conversion does not fall.

## Non-goals

- Monetization and pricing. EXD-009 defers this until activation data exists. The 5-export cap is a registration driver, not revenue.
- The free-vs-pro tier split. Deferred by explicit founder decision; this design covers guest-vs-registered only and must leave room for a third tier later.
- Fixing the `optimization_apply_failed` / `save_failed` retry loop (79 and 92 people). Real, separate work.
- Fixing the two `ReviewPromptGate` defects from 2026-08-05. The data says they are not the constraint.

## Design

### 1. Route to the result

`onAppliedOptimization` in `TailorView.swift` changes from "push diagnosis" to "go to the résumé":

- Keep: set `appState.latestOptimizationId`, `rememberJobURL`, `pendingSaveResumeId`.
- Remove: `showDiagnosis = true` and the diagnosis viewmodel construction on this path.
- Add: dismiss the pushed stack (`shouldNavigate = false`), then `onSwitchTab(.optimized)`.

Ordering matters: pop the navigation stack before switching tabs, or the tab change happens under a presented destination.

Instrumentation needs no new work. Switching the tab flips `isActive`, which fires `optimized_viewed` and `export_cta_seen` through the existing guard. Those two numbers become the proof the fix landed.

**The fit check is not in this path.** Upload, job input, and `fit_check_started/completed/optimize_tapped` all occur before apply. The only edited branch is the one that runs after an optimization has already been applied. This is the design's hard constraint and any implementation that touches the fit-check surface is out of scope.

### 2. "See what changed"

`ResumeDiagnosisView` keeps its screen and viewmodel and loses its position in the path. It becomes a link on the Optimized screen presenting before/after.

Demoting it costs almost nothing: `diagnosis_viewed` reached 5 people while 80 applied an optimization, so it is already not being seen.

### 3. Guest export

Guests export through the existing local path in `ResumeExportAction.exportPDF`: when `renderedHTML` is present, `HTMLPDFExporter` builds the PDF on-device with no token, and only falls back to the server `downloadPDF` on failure.

**This is the design's load-bearing assumption and it is unverified.** See Risks.

### 4. The cap

Client-side counter in `UserDefaults`, keyed by calendar month, limit 5.

- Exports 1-5: silent. No counter, no badge, no warning.
- Export 6: blocked. Tapping Export presents the "Save your work" sheet instead of producing a PDF. Completing registration unblocks it and the export proceeds in the same session; dismissing the sheet returns the user to the résumé with no PDF. The counter is checked before the export runs, so a blocked attempt emits `export_guest_cap_reached` and does *not* emit `export_started`.
- Reset: on month rollover, and incidentally on reinstall. Accepted. The goal is conversion, not abuse prevention, and someone who reinstalls monthly to dodge it was never going to register.
- Already-registered users are never counted or capped.

Storage sits alongside the existing `AppState` persistence helpers (`exportCompletion`, `savedResumeRecords`), not in a new subsystem.

### 5. The registration ask

After a successful export, a non-blocking sheet: **"Save your work."**

Unlocks, in the founder's words: work is saved across devices, unlimited exports, additional lift-up, expert review, design templates.

The user keeps the PDF they just produced whether or not they register. That is what makes it read as an unlock.

### 6. Review-prompt collision

The App Store review prompt currently claims its one per-version shot in `handlePDFShareDismissed`, at exactly the moment the registration ask now wants.

Registration wins. The review prompt moves to a later export.

Justification: `app_store_review_requested` has fired **once in the app's lifetime**, from the founder's own device walk on 2026-08-09. At current volume the prompt is worth nothing, and spending the export-success beat on it instead of on registration is a bad trade.

### 7. Copy

`HomeActivationState.swift:60` tells guests *"Sign in to unlock full optimization and PDF export."* This becomes false on ship.

- `.atsComplete` subheadline: rewrite to match the real gate.
- `.readyForFreeATS` subheadline: same review; it promises "unlock the full diagnosis" behind sign-in.

Both strings are user-visible and localized; update `Localizable.xcstrings` accordingly.

## Instrumentation

Existing events that answer the question without changes:

- `optimized_viewed`, `export_cta_seen` — should rise from 9 toward the apply population.
- `export_success` — the metric.
- `fit_check_optimize_tapped` — the guardrail.

New events:

| event | properties | why |
|---|---|---|
| `export_guest_cap_reached` | `month`, `export_count` | how often the cap actually bites |
| `registration_prompt_viewed` | `trigger` (`post_export` \| `cap_reached`) | separates the optional ask from the required one |
| `registration_prompt_accepted` | `trigger` | conversion |
| `registration_prompt_dismissed` | `trigger` | rejection |
| `what_changed_tapped` | `optimization_id` | whether demoting diagnosis lost anything |

Follow the existing `AnalyticsEvent` enum pattern in `Core/Analytics/AnalyticsService.swift` and extend `AnalyticsServiceTests` name assertions, as `export_cta_seen` does today.

## Success criteria

Primary: **exporters / optimizers**. Today 5 of 104, roughly 5%.

Guardrail: `fit_check_optimize_tapped` per launching user must not fall. If routing helps export but costs fit-check conversion, the change is a loss.

Secondary: `registration_prompt_accepted` / `registration_prompt_viewed`.

Read all of these only against post-release traffic on a build whose release date is store-verified, and exclude the founder person. Note that `is_internal_tester` is still not set at person level in this repo (the fix mirroring PRs #137/#138 never landed), so founder sessions currently land in the clean cohort and must be excluded by hand.

## Risks

**1. `HTMLPDFExporter` may not work for guests. Blocking.**

The whole guest-export design rests on the local render path producing a valid PDF with no token. If `renderedPreviewHTML` is empty for an unauthenticated user, export falls through to `downloadPDF`, throws `.unauthorized`, and the change relocates the wall instead of removing it.

**Verification is a prerequisite, not a build step, and the founder owns it:** export as a guest on a real device against the App Store build, confirm a valid PDF with a text layer. If it fails, this design needs a different section 3 before any implementation starts.

**2. Diagnosis navigation may already be broken.** 80 people applied, 5 saw diagnosis. This design routes around that screen rather than fixing it, so the defect survives into the "See what changed" link. Needs its own investigation; do not let it silently become part of this work.

**3. Tab-switch timing.** Switching `selectedTab` while a `navigationDestination` is presented is a known source of SwiftUI misbehavior. Pop first, then switch.

## Files touched

| file | change |
|---|---|
| `Features/Tailor/TailorView.swift` | reroute `onAppliedOptimization` |
| `Features/V2/Improve/OptimizedResumeView.swift` | "See what changed" link; registration ask; review-prompt reorder |
| `Features/V2/Home/HomeActivationState.swift` | guest copy |
| `App/AppState.swift` | monthly guest export counter |
| `Core/Analytics/AnalyticsService.swift` | five new events |
| `Resources/Localizable.xcstrings` | copy |
| tests | cap logic, month rollover, analytics names, routing |

Six source files plus tests. This clears the >3-file scope gate in the global work rules, so implementation follows `planning-protocol.md` and lands as separate stories, not one commit.

## Deferred

- Free-vs-pro differentiation.
- Server-side cap enforcement.
- The apply/save retry loop.
- `is_internal_tester` at person level.
- Whether diagnosis deserves rehabilitation or deletion.
